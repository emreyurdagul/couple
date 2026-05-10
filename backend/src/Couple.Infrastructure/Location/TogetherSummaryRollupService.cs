using Couple.Domain.Entities;
using Couple.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Couple.Infrastructure.Location;

/// <summary>
/// Her gece UTC 03:17'de bir önceki günün <see cref="DailyTogetherSummary"/> kayıtlarını
/// tüm aktif couple'lar için compute eder. Bugünü kapsayan sorgu lazy hesaplama yapar
/// (bkz. <see cref="LocationService.GetTogetherSummaryAsync"/>).
/// </summary>
public class TogetherSummaryRollupService : BackgroundService
{
    private static readonly TimeSpan DailyAtUtc = new(3, 17, 0);

    private readonly IServiceScopeFactory _scopes;
    private readonly ILogger<TogetherSummaryRollupService> _log;

    public TogetherSummaryRollupService(IServiceScopeFactory scopes, ILogger<TogetherSummaryRollupService> log)
    {
        _scopes = scopes;
        _log = log;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var delay = NextRunDelay(DateTimeOffset.UtcNow);
                await Task.Delay(delay, stoppingToken);
                await RollupYesterdayAsync(stoppingToken);
            }
            catch (OperationCanceledException) { break; }
            catch (Exception ex)
            {
                _log.LogError(ex, "TogetherSummaryRollupService run failed");
                // 5 dakika sonra tekrar dene
                try { await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken); }
                catch (OperationCanceledException) { break; }
            }
        }
    }

    internal static TimeSpan NextRunDelay(DateTimeOffset now)
    {
        var nextUtc = new DateTimeOffset(
            now.UtcDateTime.Date.Add(DailyAtUtc), TimeSpan.Zero);
        if (nextUtc <= now) nextUtc = nextUtc.AddDays(1);
        return nextUtc - now;
    }

    private async Task RollupYesterdayAsync(CancellationToken ct)
    {
        await using var scope = _scopes.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<CoupleDbContext>();
        var calc = scope.ServiceProvider.GetRequiredService<TogetherCalculator>();

        var yesterday = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(-1));
        var dayStart = new DateTimeOffset(yesterday.ToDateTime(TimeOnly.MinValue), TimeSpan.Zero);
        var dayEnd = dayStart.AddDays(1);

        var couples = await db.Couples
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(c => c.Status == CoupleStatus.Active)
            .Select(c => c.Id)
            .ToListAsync(ct);

        var settings = await db.CoupleSettings
            .IgnoreQueryFilters()
            .AsNoTracking()
            .ToDictionaryAsync(s => s.CoupleId, ct);

        foreach (var coupleId in couples)
        {
            var threshold = settings.TryGetValue(coupleId, out var s) ? s.TogetherDistanceMeters : 50;
            var minutes = await calc.ComputeMinutesAsync(coupleId, dayStart, dayEnd, threshold, ct);

            var existing = await db.DailyTogetherSummaries
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(x => x.CoupleId == coupleId && x.Date == yesterday, ct);

            var firstAt = await GetFirstTogetherAtAsync(db, coupleId, dayStart, dayEnd, threshold, ct);
            var lastAt = await GetLastTogetherAtAsync(db, coupleId, dayStart, dayEnd, threshold, ct);

            if (existing is null)
            {
                db.DailyTogetherSummaries.Add(new DailyTogetherSummary
                {
                    Id = Guid.CreateVersion7(),
                    CoupleId = coupleId,
                    Date = yesterday,
                    TogetherMinutes = minutes,
                    FirstTogetherAt = firstAt,
                    LastTogetherAt = lastAt,
                    ComputedAt = DateTimeOffset.UtcNow,
                });
            }
            else
            {
                existing.TogetherMinutes = minutes;
                existing.FirstTogetherAt = firstAt;
                existing.LastTogetherAt = lastAt;
                existing.ComputedAt = DateTimeOffset.UtcNow;
            }
        }
        await db.SaveChangesAsync(ct);
        _log.LogInformation("Together rollup completed for {Date}: {Count} couples", yesterday, couples.Count);
    }

    private static async Task<DateTimeOffset?> GetFirstTogetherAtAsync(
        CoupleDbContext db, Guid coupleId, DateTimeOffset from, DateTimeOffset to, int threshold, CancellationToken ct)
    {
        const string sql = """
            WITH bucketed AS (
                SELECT
                    "UserId",
                    date_trunc('minute', "RecordedAt") AS bucket,
                    AVG(ST_X("Position"::geometry)) AS lng,
                    AVG(ST_Y("Position"::geometry)) AS lat
                FROM "LocationPoints"
                WHERE "CoupleId" = {0}
                  AND "RecordedAt" >= {1} AND "RecordedAt" < {2}
                  AND ("Accuracy" IS NULL OR "Accuracy" <= 50)
                GROUP BY "UserId", bucket
            )
            SELECT MIN(a.bucket) AS "Value"
            FROM bucketed a JOIN bucketed b
              ON a.bucket = b.bucket AND a."UserId" < b."UserId"
            WHERE ST_Distance(
                ST_SetSRID(ST_MakePoint(a.lng, a.lat), 4326)::geography,
                ST_SetSRID(ST_MakePoint(b.lng, b.lat), 4326)::geography
            ) < {3}
            """;
        var result = await db.Database
            .SqlQueryRaw<DateTime?>(sql, coupleId, from, to, (double)threshold)
            .FirstOrDefaultAsync(ct);
        return result is null ? null : new DateTimeOffset(DateTime.SpecifyKind(result.Value, DateTimeKind.Utc));
    }

    private static async Task<DateTimeOffset?> GetLastTogetherAtAsync(
        CoupleDbContext db, Guid coupleId, DateTimeOffset from, DateTimeOffset to, int threshold, CancellationToken ct)
    {
        const string sql = """
            WITH bucketed AS (
                SELECT
                    "UserId",
                    date_trunc('minute', "RecordedAt") AS bucket,
                    AVG(ST_X("Position"::geometry)) AS lng,
                    AVG(ST_Y("Position"::geometry)) AS lat
                FROM "LocationPoints"
                WHERE "CoupleId" = {0}
                  AND "RecordedAt" >= {1} AND "RecordedAt" < {2}
                  AND ("Accuracy" IS NULL OR "Accuracy" <= 50)
                GROUP BY "UserId", bucket
            )
            SELECT MAX(a.bucket) AS "Value"
            FROM bucketed a JOIN bucketed b
              ON a.bucket = b.bucket AND a."UserId" < b."UserId"
            WHERE ST_Distance(
                ST_SetSRID(ST_MakePoint(a.lng, a.lat), 4326)::geography,
                ST_SetSRID(ST_MakePoint(b.lng, b.lat), 4326)::geography
            ) < {3}
            """;
        var result = await db.Database
            .SqlQueryRaw<DateTime?>(sql, coupleId, from, to, (double)threshold)
            .FirstOrDefaultAsync(ct);
        return result is null ? null : new DateTimeOffset(DateTime.SpecifyKind(result.Value, DateTimeKind.Utc));
    }
}
