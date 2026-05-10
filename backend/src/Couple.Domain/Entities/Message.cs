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
}
