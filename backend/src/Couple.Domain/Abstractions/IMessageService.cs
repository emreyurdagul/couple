using Couple.Domain.Entities;

namespace Couple.Domain.Abstractions;

public record MessageInput(
    Guid Id,
    MessageType Type,
    string? Content,
    string? Payload,
    string? MediaObjectKey,
    string? MediaMimeType,
    int? MediaDurationMs,
    long? MediaSizeBytes,
    Guid? ReplyToMessageId = null);

public record MessageWithReactions(Message Message, List<MessageReaction> Reactions);

public enum DeleteScope { ForMe, ForBoth }

public class EditWindowExpiredException : Exception
{
    public EditWindowExpiredException() : base("edit_window_expired") { }
}

public class MessageNotFoundException : Exception
{
    public MessageNotFoundException() : base("message_not_found") { }
}

public class NotMessageSenderException : Exception
{
    public NotMessageSenderException() : base("not_message_sender") { }
}

public interface IMessageService
{
    /// <summary>
    /// Idempotent upsert. Aynı <see cref="MessageInput.Id"/> ile çağrı varolan kaydı döndürür
    /// (insert yapmaz). Couple scope <see cref="ICurrentUser"/>'dan otomatik gelir.
    /// </summary>
    Task<Message> UpsertAsync(MessageInput input, CancellationToken ct = default);

    /// <summary>
    /// <paramref name="sinceCursor"/> sonrası gelen mesajlar; cursor ServerReceivedAt
    /// timestamp'ı (exclusive). Null ise en yeni N kayıt döner (created desc).
    /// "for me" silinmiş mesajlar mevcut kullanıcı için filtrelenir.
    /// Her mesajla birlikte reactions listesi döner.
    /// </summary>
    Task<List<MessageWithReactions>> ListAsync(
        DateTimeOffset? sinceCursor,
        int take,
        CancellationToken ct = default);

    Task<MessageWithReactions?> GetAsync(Guid messageId, CancellationToken ct = default);

    Task MarkReadAsync(Guid messageId, CancellationToken ct = default);

    /// <summary>
    /// Reaction ekler (idempotent: aynı user+emoji varsa hiçbir şey yapmaz, mevcut kaydı döner).
    /// </summary>
    Task<MessageReaction> AddReactionAsync(Guid messageId, string emoji, CancellationToken ct = default);

    /// <summary>
    /// Reaction kaldırır. Yoksa sessizce 204.
    /// </summary>
    Task RemoveReactionAsync(Guid messageId, string emoji, CancellationToken ct = default);

    /// <summary>
    /// Mesaj içeriğini günceller. Yalnız sender, yalnız 15 dakika içinde.
    /// </summary>
    Task<Message> EditAsync(Guid messageId, string content, CancellationToken ct = default);

    /// <summary>
    /// Silme. <see cref="DeleteScope.ForMe"/> sadece çağıran kullanıcı için gizler;
    /// <see cref="DeleteScope.ForBoth"/> sender değilse reddedilir, hard soft-delete (DeletedAt).
    /// </summary>
    Task DeleteAsync(Guid messageId, DeleteScope scope, CancellationToken ct = default);
}
