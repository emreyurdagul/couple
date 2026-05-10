using Couple.Domain.Abstractions;
using NetTopologySuite.Geometries;

namespace Couple.Domain.Entities;

public class LocationPoint : ICoupleScoped
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid CoupleId { get; set; }
    public Point Position { get; set; } = null!;
    public double? Accuracy { get; set; }
    public double? Speed { get; set; }
    public double? Heading { get; set; }
    public int? BatteryLevel { get; set; }
    public bool IsMoving { get; set; }
    public DateTimeOffset RecordedAt { get; set; }
    public DateTimeOffset ReceivedAt { get; set; }
}
