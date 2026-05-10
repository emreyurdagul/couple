using Couple.Domain.Abstractions;

namespace Couple.Domain.Entities;

public enum MessageType
{
    Text = 0,
    Image = 1,
    Voice = 2,
    System = 3,
    Custom = 99,
}

public class Message : ICoupleScoped
{
    public Guid Id { get; set; }
    public Guid CoupleId { get; set; }
    public Guid SenderId { get; set; }
    public MessageType Type { get; set; }
    public string? Content { get; set; }
    public string? Payload { get; set; }
    public string? MediaObjectKey { get; set; }
    public string? MediaMimeType { get; set; }
    public int? MediaDurationMs { get; set; }
    public long? MediaSizeBytes { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? ReadAt { get; set; }
    public DateTimeOffset ServerReceivedAt { get; set; }

    // 3.2 — rich messages
    public Guid? ReplyToMessageId { get; set; }
    public DateTimeOffset? EditedAt { get; set; }
    public DateTimeOffset? DeletedAt { get; set; }
    public Guid? DeletedByUserId { get; set; }

    // 3.3 — pin
    public bool IsPinned { get; set; }
    public DateTimeOffset? PinnedAt { get; set; }

    // 3.4 — TTL (couple ayarından gelir)
    public DateTimeOffset? ExpiresAt { get; set; }

    // 4.5 — anlık fotoğraf
    public bool IsEphemeral { get; set; }
    public DateTimeOffset? ViewedAt { get; set; }
}
