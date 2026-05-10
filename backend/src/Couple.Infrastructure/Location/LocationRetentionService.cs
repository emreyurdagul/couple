using Couple.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Couple.Infrastructure.Location;

/// <summary>
/// Her gün bir kez, her couple için <c>CoupleSettings.LocationHistoryRetentionDays</c> günden
/// eski <c>LocationPoint</c> kayıtlarını siler. Default 90 gün.
/// </summary>
public class LocationRetentionService : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromHours(24);
    private static readonly TimeSpan StartupDelay = TimeSpan.FromMinutes(2);

    private readonly IServiceScopeFactory _scopes;
    private readonly ILogger<LocationRetentionService> _log;

    public LocationRetentionService(IServiceScopeFactory scopes, ILogger<LocationRetentionService> log)
    {
        _scopes = scopes;
        _log = log;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        try { await Task.Delay(StartupDelay, stoppingToken); }
        catch (OperationCanceledException) { return; }

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await PurgeOnceAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _log.LogError(ex, "LocationRetentionService run failed");
            }
            try { await Task.Delay(Interval, stoppingToken); }
            catch (OperationCanceledException) { break; }
        }
    }

    private async Task PurgeOnceAsync(CancellationToken ct)
    {
        await using var scope = _scopes.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<CoupleDbContext>();

        var settings = await db.CoupleSettings.IgnoreQueryFilters().AsNoTracking().ToListAsync(ct);
        var totalDeleted = 0L;
        foreach (var s in settings)
        {
            var cutoff = DateTimeOffset.UtcNow.AddDays(-s.LocationHistoryRetentionDays);
            var deleted = await db.LocationPoints
                .IgnoreQueryFilters()
                .Where(p => p.CoupleId == s.CoupleId && p.RecordedAt < cutoff)
                .ExecuteDeleteAsync(ct);
            totalDeleted += deleted;
        }
        _log.LogInformation("LocationRetentionService purged {Count} rows across {Couples} couples", totalDeleted, settings.Count);
    }
}
