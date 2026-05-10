using Couple.Domain.Abstractions;
using Couple.Domain.Entities;

namespace Couple.Api.Endpoints;

public record ReactionDto(Guid Id, Guid UserId, string Emoji, DateTimeOffset CreatedAt)
{
    public static ReactionDto From(MessageReaction r) =>
        new(r.Id, r.UserId, r.Emoji, r.CreatedAt);
}

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
    DateTimeOffset ServerReceivedAt,
    Guid? ReplyToMessageId,
    DateTimeOffset? EditedAt,
    DateTimeOffset? DeletedAt,
    Guid? DeletedByUserId,
    bool IsPinned,
    DateTimeOffset? PinnedAt,
    DateTimeOffset? ExpiresAt,
    bool IsEphemeral,
    DateTimeOffset? ViewedAt,
    IReadOnlyList<ReactionDto> Reactions)
{
    public static MessageDto From(Message m, IEnumerable<MessageReaction>? reactions = null) => new(
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
        m.ServerReceivedAt,
        m.ReplyToMessageId,
        m.EditedAt,
        m.DeletedAt,
        m.DeletedByUserId,
        m.IsPinned,
        m.PinnedAt,
        m.ExpiresAt,
        m.IsEphemeral,
        m.ViewedAt,
        (reactions ?? []).Select(ReactionDto.From).ToList());

    public static MessageDto From(MessageWithReactions m) => From(m.Message, m.Reactions);
}
