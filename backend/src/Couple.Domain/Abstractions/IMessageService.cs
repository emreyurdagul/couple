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
    long? MediaSizeBytes);

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
    /// </summary>
    Task<List<Message>> ListAsync(DateTimeOffset? sinceCursor, int take, CancellationToken ct = default);

    Task MarkReadAsync(Guid messageId, CancellationToken ct = default);
}
