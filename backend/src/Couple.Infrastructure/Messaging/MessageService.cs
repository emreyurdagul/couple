using Couple.Domain.Abstractions;
using Couple.Domain.Entities;
using Couple.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Couple.Infrastructure.Messaging;

public class MessageService : IMessageService
{
    private static readonly TimeSpan EditWindow = TimeSpan.FromMinutes(15);

    private readonly CoupleDbContext _db;
    private readonly ICurrentUser _currentUser;

    public MessageService(CoupleDbContext db, ICurrentUser currentUser)
    {
        _db = db;
        _currentUser = currentUser;
    }

    public async Task<Message> UpsertAsync(MessageInput input, CancellationToken ct = default)
    {
        EnsureScope(out var coupleId, out var userId);

        var existing = await _db.Messages.FirstOrDefaultAsync(m => m.Id == input.Id, ct);
        if (existing is not null)
        {
            if (existing.CoupleId != coupleId || existing.SenderId != userId)
                throw new UnauthorizedAccessException("Message id collision across couples.");
            return existing;
        }

        // ReplyToMessageId varsa aynı couple'da olmalı
        if (input.ReplyToMessageId is { } replyId)
        {
            var quotedExists = await _db.Messages
                .AnyAsync(m => m.Id == replyId, ct);
            if (!quotedExists)
                throw new MessageNotFoundException();
        }

        var now = DateTimeOffset.UtcNow;
        var message = new Message
        {
            Id = input.Id,
            CoupleId = coupleId,
            SenderId = userId,
            Type = input.Type,
            Content = input.Content,
            Payload = input.Payload,
            MediaObjectKey = input.MediaObjectKey,
            MediaMimeType = input.MediaMimeType,
            MediaDurationMs = input.MediaDurationMs,
            MediaSizeBytes = input.MediaSizeBytes,
            CreatedAt = now,
            ServerReceivedAt = now,
            ReplyToMessageId = input.ReplyToMessageId,
        };
        _db.Messages.Add(message);
        await _db.SaveChangesAsync(ct);
        return message;
    }

    public async Task<List<MessageWithReactions>> ListAsync(
        DateTimeOffset? sinceCursor,
        int take,
        CancellationToken ct = default)
    {
        EnsureScope(out _, out var userId);
        var capped = Math.Clamp(take, 1, 200);

        // "for me" silinen mesajları çıkar
        var hiddenIds = await _db.MessageDeletedForUsers
            .Where(d => d.UserId == userId)
            .Select(d => d.MessageId)
            .ToListAsync(ct);
        var hidden = hiddenIds.ToHashSet();

        IQueryable<Message> q = _db.Messages.AsNoTracking();
        if (sinceCursor is { } since)
        {
            q = q.Where(m => m.ServerReceivedAt > since)
                 .OrderBy(m => m.ServerReceivedAt);
        }
        else
        {
            q = q.OrderByDescending(m => m.CreatedAt);
        }
        var messages = await q.Take(capped).ToListAsync(ct);
        var visible = messages.Where(m => !hidden.Contains(m.Id)).ToList();

        if (visible.Count == 0) return new List<MessageWithReactions>();

        var ids = visible.Select(m => m.Id).ToList();
        var reactions = await _db.MessageReactions
            .AsNoTracking()
            .Where(r => ids.Contains(r.MessageId))
            .ToListAsync(ct);
        var byMessage = reactions
            .GroupBy(r => r.MessageId)
            .ToDictionary(g => g.Key, g => g.ToList());

        return visible
            .Select(m => new MessageWithReactions(
                m,
                byMessage.TryGetValue(m.Id, out var list) ? list : new()))
            .ToList();
    }

    public async Task<MessageWithReactions?> GetAsync(Guid messageId, CancellationToken ct = default)
    {
        EnsureScope(out _, out var userId);
        var hidden = await _db.MessageDeletedForUsers
            .AnyAsync(d => d.MessageId == messageId && d.UserId == userId, ct);
        if (hidden) return null;
        var msg = await _db.Messages.AsNoTracking()
            .FirstOrDefaultAsync(m => m.Id == messageId, ct);
        if (msg is null) return null;
        var reactions = await _db.MessageReactions.AsNoTracking()
            .Where(r => r.MessageId == messageId).ToListAsync(ct);
        return new MessageWithReactions(msg, reactions);
    }

    public async Task MarkReadAsync(Guid messageId, CancellationToken ct = default)
    {
        EnsureScope(out _, out var userId);
        var msg = await _db.Messages.FirstOrDefaultAsync(m => m.Id == messageId, ct);
        if (msg is null) return;
        if (msg.SenderId == userId) return;
        if (msg.ReadAt is not null) return;
        msg.ReadAt = DateTimeOffset.UtcNow;
        await _db.SaveChangesAsync(ct);
    }

    public async Task<MessageReaction> AddReactionAsync(
        Guid messageId,
        string emoji,
        CancellationToken ct = default)
    {
        EnsureScope(out _, out var userId);
        var clean = emoji.Trim();
        if (string.IsNullOrEmpty(clean) || clean.Length > 16)
            throw new ArgumentException("emoji_invalid", nameof(emoji));

        var msg = await _db.Messages
            .FirstOrDefaultAsync(m => m.Id == messageId, ct)
            ?? throw new MessageNotFoundException();
        if (msg.DeletedAt is not null)
            throw new MessageNotFoundException();

        var existing = await _db.MessageReactions
            .FirstOrDefaultAsync(r =>
                r.MessageId == messageId && r.UserId == userId && r.Emoji == clean, ct);
        if (existing is not null) return existing;

        var reaction = new MessageReaction
        {
            Id = Guid.CreateVersion7(),
            MessageId = messageId,
            UserId = userId,
            Emoji = clean,
            CreatedAt = DateTimeOffset.UtcNow,
        };
        _db.MessageReactions.Add(reaction);
        await _db.SaveChangesAsync(ct);
        return reaction;
    }

    public async Task RemoveReactionAsync(
        Guid messageId,
        string emoji,
        CancellationToken ct = default)
    {
        EnsureScope(out _, out var userId);
        var clean = emoji.Trim();
        await _db.MessageReactions
            .Where(r => r.MessageId == messageId
                     && r.UserId == userId
                     && r.Emoji == clean)
            .ExecuteDeleteAsync(ct);
    }

    public async Task<Message> EditAsync(
        Guid messageId,
        string content,
        CancellationToken ct = default)
    {
        EnsureScope(out _, out var userId);
        var trimmed = content.Trim();
        if (trimmed.Length == 0)
            throw new ArgumentException("content_empty", nameof(content));
        if (trimmed.Length > 4000)
            throw new ArgumentException("content_too_long", nameof(content));

        var msg = await _db.Messages.FirstOrDefaultAsync(m => m.Id == messageId, ct)
            ?? throw new MessageNotFoundException();

        if (msg.DeletedAt is not null) throw new MessageNotFoundException();
        if (msg.SenderId != userId) throw new NotMessageSenderException();
        if (msg.Type != MessageType.Text) throw new InvalidOperationException("only_text_editable");
        if (DateTimeOffset.UtcNow - msg.CreatedAt > EditWindow)
            throw new EditWindowExpiredException();

        msg.Content = trimmed;
        msg.EditedAt = DateTimeOffset.UtcNow;
        await _db.SaveChangesAsync(ct);
        return msg;
    }

    public async Task DeleteAsync(
        Guid messageId,
        DeleteScope scope,
        CancellationToken ct = default)
    {
        EnsureScope(out var coupleId, out var userId);
        var msg = await _db.Messages.FirstOrDefaultAsync(m => m.Id == messageId, ct)
            ?? throw new MessageNotFoundException();

        if (scope == DeleteScope.ForMe)
        {
            // Idempotent — aynı kullanıcı tekrar silmeye çalışırsa boşver
            var alreadyHidden = await _db.MessageDeletedForUsers
                .AnyAsync(d => d.MessageId == messageId && d.UserId == userId, ct);
            if (alreadyHidden) return;

            _db.MessageDeletedForUsers.Add(new MessageDeletedForUser
            {
                Id = Guid.CreateVersion7(),
                CoupleId = coupleId,
                MessageId = messageId,
                UserId = userId,
                DeletedAt = DateTimeOffset.UtcNow,
            });
            await _db.SaveChangesAsync(ct);
            return;
        }

        // ForBoth — sender check
        if (msg.SenderId != userId) throw new NotMessageSenderException();
        if (msg.DeletedAt is not null) return; // idempotent
        msg.DeletedAt = DateTimeOffset.UtcNow;
        msg.DeletedByUserId = userId;
        // İçerik temizleme: text mesajlarında content nullify (medya zaten medya servisi ile temizlenir)
        msg.Content = null;
        msg.Payload = null;
        await _db.SaveChangesAsync(ct);
    }

    private void EnsureScope(out Guid coupleId, out Guid userId)
    {
        if (_currentUser.UserId is null || _currentUser.CoupleId is null)
            throw new UnauthorizedAccessException("Caller has no active couple.");
        coupleId = _currentUser.CoupleId.Value;
        userId = _currentUser.UserId.Value;
    }
}
