using Couple.Domain.Abstractions;
using Couple.Domain.Entities;
using Couple.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;

namespace Couple.Infrastructure.Location;

public class LocationService : ILocationService
{
    private readonly CoupleDbContext _db;
    private readonly ICurrentUser _currentUser;
    private readonly TogetherCalculator _together;

    public LocationService(CoupleDbContext db, ICurrentUser currentUser, TogetherCalculator together)
    {
        _db = db;
        _currentUser = currentUser;
        _together = together;
    }

    public async Task<LocationPoint> RecordAsync(LocationInput input, CancellationToken ct = default)
    {
        EnsureScope(out var coupleId, out var userId);
        await EnsureSharingEnabledAsync(coupleId, ct);
        var point = ToEntity(input, coupleId, userId, DateTimeOffset.UtcNow);
        _db.LocationPoints.Add(point);
        await _db.SaveChangesAsync(ct);
        return point;
    }

    public async Task<List<LocationPoint>> RecordBatchAsync(
        IReadOnlyList<LocationInput> inputs,
        CancellationToken ct = default)
    {
        EnsureScope(out var coupleId, out var userId);
        if (inputs.Count == 0) return new List<LocationPoint>();
        await EnsureSharingEnabledAsync(coupleId, ct);

        var now = DateTimeOffset.UtcNow;
        var entities = inputs.Select(i => ToEntity(i, coupleId, userId, now)).ToList();
        _db.LocationPoints.AddRange(entities);
        await _db.SaveChangesAsync(ct);
        return entities;
    }

    public async Task<LocationDto?> GetPartnerCurrentAsync(CancellationToken ct = default)
    {
        EnsureScope(out var coupleId, out var userId);
        var partnerId = await GetPartnerUserIdAsync(coupleId, userId, ct);
        if (partnerId is null) return null;

        var last = await _db.LocationPoints.AsNoTracking()
            .Where(p => p.UserId == partnerId.Value)
            .OrderByDescending(p => p.RecordedAt)
            .FirstOrDefaultAsync(ct);
        return last is null ? null : ToDto(last);
    }

    public async Task<List<LocationDto>> ListAsync(
        DateTimeOffset from,
        DateTimeOffset to,
        int maxPoints,
        CancellationToken ct = default)
    {
        EnsureScope(out _, out _);
        var capped = Math.Clamp(maxPoints, 1, 5000);
        var rows = await _db.LocationPoints.AsNoTracking()
            .Where(p => p.RecordedAt >= from && p.RecordedAt <= to)
            .OrderBy(p => p.RecordedAt)
            .Take(capped)
            .ToListAsync(ct);
        return rows.Select(ToDto).ToList();
    }

    public async Task<TogetherSummary> GetTogetherSummaryAsync(
        DateTimeOffset from,
        DateTimeOffset to,
        CancellationToken ct = default)
    {
        EnsureScope(out var coupleId, out _);
        if (to < from) (from, to) = (to, from);

        var settings = await GetSettingsAsync(coupleId, ct);
        var threshold = settings.TogetherDistanceMeters;

        var todayUtc = DateOnly.FromDateTime(DateTime.UtcNow);
        var fromDay = DateOnly.FromDateTime(from.UtcDateTime);
        var toDay = DateOnly.FromDateTime(to.UtcDateTime);

        var byDay = new List<TogetherDay>();
        for (var d = fromDay; d <= toDay; d = d.AddDays(1))
        {
            int minutes;
            if (d < todayUtc)
            {
                var stored = await _db.DailyTogetherSummaries.AsNoTracking()
                    .FirstOrDefaultAsync(s => s.Date == d, ct);
                minutes = stored?.TogetherMinutes ?? 0;
            }
            else
            {
                var dayStart = new DateTimeOffset(d.ToDateTime(TimeOnly.MinValue), TimeSpan.Zero);
                var dayEnd = dayStart.AddDays(1).AddTicks(-1);
                var rangeFrom = d == fromDay && from > dayStart ? from : dayStart;
                var rangeTo = d == toDay && to < dayEnd ? to : dayEnd;
                minutes = await _together.ComputeMinutesAsync(coupleId, rangeFrom, rangeTo, threshold, ct);
            }
            byDay.Add(new TogetherDay(d, minutes));
        }

        return new TogetherSummary(from, to, byDay.Sum(x => x.TogetherMinutes), byDay);
    }

    private async Task<Guid?> GetPartnerUserIdAsync(Guid coupleId, Guid userId, CancellationToken ct)
    {
        var couple = await _db.Couples.AsNoTracking()
            .FirstOrDefaultAsync(c => c.Id == coupleId, ct);
        if (couple is null) return null;
        return couple.User1Id == userId ? couple.User2Id : couple.User1Id;
    }

    private async Task<CoupleSettings> GetSettingsAsync(Guid coupleId, CancellationToken ct)
    {
        var s = await _db.CoupleSettings.AsNoTracking().FirstOrDefaultAsync(ct);
        return s ?? new CoupleSettings { CoupleId = coupleId };
    }

    private async Task EnsureSharingEnabledAsync(Guid coupleId, CancellationToken ct)
    {
        var s = await GetSettingsAsync(coupleId, ct);
        if (!s.LocationSharingEnabled) throw new LocationSharingDisabledException();
    }

    private static LocationPoint ToEntity(LocationInput i, Guid coupleId, Guid userId, DateTimeOffset receivedAt) =>
        new()
        {
            Id = Guid.CreateVersion7(),
            CoupleId = coupleId,
            UserId = userId,
            Position = new Point(i.Longitude, i.Latitude) { SRID = 4326 },
            Accuracy = i.Accuracy,
            Speed = i.Speed,
            Heading = i.Heading,
            BatteryLevel = i.BatteryLevel,
            IsMoving = i.IsMoving,
            RecordedAt = i.RecordedAt,
            ReceivedAt = receivedAt,
        };

    private static LocationDto ToDto(LocationPoint p) => new(
        p.Id, p.UserId, p.Position.Y, p.Position.X,
        p.Accuracy, p.Speed, p.Heading, p.BatteryLevel, p.IsMoving,
        p.RecordedAt, p.ReceivedAt);

    private void EnsureScope(out Guid coupleId, out Guid userId)
    {
        if (_currentUser.UserId is null || _currentUser.CoupleId is null)
            throw new UnauthorizedAccessException("Caller has no active couple.");
        coupleId = _currentUser.CoupleId.Value;
        userId = _currentUser.UserId.Value;
    }
}
