using Couple.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Couple.Infrastructure.Location;

public class TogetherCalculator
{
    private readonly CoupleDbContext _db;

    public TogetherCalculator(CoupleDbContext db)
    {
        _db = db;
    }

    public async Task<int> ComputeMinutesAsync(
        Guid coupleId,
        DateTimeOffset from,
        DateTimeOffset to,
        int distanceThresholdMeters,
        CancellationToken ct = default)
    {
        if (to <= from) return 0;

        const string sql = """
            WITH bucketed AS (
                SELECT
                    "UserId",
                    date_trunc('minute', "RecordedAt") AS bucket,
                    AVG(ST_X("Position"::geometry)) AS lng,
                    AVG(ST_Y("Position"::geometry)) AS lat
                FROM "LocationPoints"
                WHERE "CoupleId" = {0}
                  AND "RecordedAt" >= {1}
                  AND "RecordedAt" <  {2}
                  AND ("Accuracy" IS NULL OR "Accuracy" <= 50)
                GROUP BY "UserId", bucket
            ),
            paired AS (
                SELECT a.bucket
                FROM bucketed a
                JOIN bucketed b
                  ON a.bucket = b.bucket
                 AND a."UserId" < b."UserId"
                WHERE ST_Distance(
                    ST_SetSRID(ST_MakePoint(a.lng, a.lat), 4326)::geography,
                    ST_SetSRID(ST_MakePoint(b.lng, b.lat), 4326)::geography
                ) < {3}
            )
            SELECT COUNT(*)::int4 AS "Value" FROM paired
            """;

        var result = await _db.Database
            .SqlQueryRaw<int>(sql, coupleId, from, to, (double)distanceThresholdMeters)
            .FirstAsync(ct);
        return result;
    }
}
