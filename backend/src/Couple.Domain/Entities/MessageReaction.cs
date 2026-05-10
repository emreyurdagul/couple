using Couple.Domain.Abstractions;

namespace Couple.Domain.Entities;

public class MessageReaction : ICoupleScoped
{
    public Guid Id { get; set; }
    public Guid CoupleId { get; set; }
    public Guid MessageId { get; set; }
    public Guid UserId { get; set; }
    public string Emoji { get; set; } = string.Empty;
    public DateTimeOffset CreatedAt { get; set; }
}
