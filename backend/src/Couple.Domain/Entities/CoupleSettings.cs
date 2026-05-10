using Couple.Domain.Abstractions;

namespace Couple.Domain.Entities;

public class CoupleSettings : ICoupleScoped
{
    public Guid Id { get; set; }
    public Guid CoupleId { get; set; }

    public bool LocationSharingEnabled { get; set; } = true;

    public int TogetherDistanceMeters { get; set; } = 50;

    public int LocationHistoryRetentionDays { get; set; } = 90;

    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}
