using Couple.Domain.Entities;

namespace Couple.Api.Endpoints;

public record MessageDto(
    Guid Id,
    Guid CoupleId,
    Guid SenderId,
    string Type,
    string? Content,
    string? Payload,
    string? MediaObjectKey,
    string? MediaMimeType,
    int? MediaDurationMs,
    long? MediaSizeBytes,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ReadAt,
    DateTimeOffset ServerReceivedAt)
{
    public static MessageDto From(Message m) => new(
        m.Id,
        m.CoupleId,
        m.SenderId,
        m.Type.ToString(),
        m.Content,
        m.Payload,
        m.MediaObjectKey,
        m.MediaMimeType,
        m.MediaDurationMs,
        m.MediaSizeBytes,
        m.CreatedAt,
        m.ReadAt,
        m.ServerReceivedAt);
}
