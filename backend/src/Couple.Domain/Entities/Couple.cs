namespace Couple.Domain.Entities;

public enum CoupleStatus
{
    Pending = 0,
    Active = 1,
    Ended = 2,
}

public class Couple
{
    public Guid Id { get; set; }
    public Guid User1Id { get; set; }
    public Guid User2Id { get; set; }
    public CoupleStatus Status { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? EndedAt { get; set; }
}
