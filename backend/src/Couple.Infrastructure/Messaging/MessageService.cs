using Couple.Domain.Abstractions;
using Couple.Domain.Entities;
using Couple.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Couple.Infrastructure.Messaging;

public class MessageService : IMessageService
{
    private readonly CoupleDbContext _db;
    private readonly ICurrentUser _currentUser;

    public MessageService(CoupleDbContext db, ICurrentUser currentUser)
    {
        _db = db;
        _currentUser = currentUser;
    }

    public async Task<Message> UpsertAsync(MessageInput input, CancellationToken ct = default)
    {
        if (_currentUser.UserId is null || _currentUser.CoupleId is null)
            throw new UnauthorizedAccessException("Caller has no active couple.");

        // Idempotency: aynı Id ile gelen tekrar isteklerde mevcut kaydı döndür.
        // IgnoreQueryFilters: aynı kaydı sender değilse de doğrulayabilmek için global filter kullanılır;
        // ama scope kontrolü interceptor tarafından zaten yapılır.
        var existing = await _db.Messages
            .FirstOrDefaultAsync(m => m.Id == input.Id, ct);
        if (existing is not null)
        {
            // Sender + couple farklı ise scope mismatch — interceptor olmasa da guard
            if (existing.CoupleId != _currentUser.CoupleId.Value
                || existing.SenderId != _currentUser.UserId.Value)
                throw new UnauthorizedAccessException("Message id collision across couples.");
            return existing;
        }

        var now = DateTimeOffset.UtcNow;
        var message = new Message
        {
            Id = input.Id,
            CoupleId = _currentUser.CoupleId.Value,
            SenderId = _currentUser.UserId.Value,
            Type = input.Type,
            Content = input.Content,
            Payload = input.Payload,
            MediaObjectKey = input.MediaObjectKey,
            MediaMimeType = input.MediaMimeType,
            MediaDurationMs = input.MediaDurationMs,
            MediaSizeBytes = input.MediaSizeBytes,
            CreatedAt = now,
            ServerReceivedAt = now,
        };
        _db.Messages.Add(message);
        await _db.SaveChangesAsync(ct);
        return message;
    }

    public async Task<List<Message>> ListAsync(
        DateTimeOffset? sinceCursor,
        int take,
        CancellationToken ct = default)
    {
        var capped = Math.Clamp(take, 1, 200);
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
        return await q.Take(capped).ToListAsync(ct);
    }

    public async Task MarkReadAsync(Guid messageId, CancellationToken ct = default)
    {
        if (_currentUser.UserId is null) return;
        var msg = await _db.Messages.FirstOrDefaultAsync(m => m.Id == messageId, ct);
        if (msg is null) return;
        if (msg.SenderId == _currentUser.UserId.Value) return; // kendi mesajını işaretleme
        if (msg.ReadAt is not null) return;
        msg.ReadAt = DateTimeOffset.UtcNow;
        await _db.SaveChangesAsync(ct);
    }
}
