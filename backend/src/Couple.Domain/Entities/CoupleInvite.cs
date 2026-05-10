namespace Couple.Domain.Entities;

public class CoupleInvite
{
    public Guid Id { get; set; }
    public Guid FromUserId { get; set; }
    public string Code { get; set; } = string.Empty;
    public DateTimeOffset ExpiresAt { get; set; }
    public Guid? ConsumedByUserId { get; set; }
    public DateTimeOffset? ConsumedAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}
