using Couple.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Couple.Infrastructure.Outbox;

/// <summary>
/// Drains OutboxEvents and ships them to external sinks (FCM, partner notification, …).
/// MVP: marks events as dispatched. Real handlers wired in Phase 3+.
/// </summary>
public class OutboxDispatcher : BackgroundService
{
    private static readonly TimeSpan PollInterval = TimeSpan.FromSeconds(2);
    private const int BatchSize = 32;

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<OutboxDispatcher> _logger;

    public OutboxDispatcher(IServiceScopeFactory scopeFactory, ILogger<OutboxDispatcher> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await DrainBatchAsync(stoppingToken);
            }
            catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
            {
                _logger.LogError(ex, "Outbox dispatch loop error");
            }

            try { await Task.Delay(PollInterval, stoppingToken); }
            catch (TaskCanceledException) { break; }
        }
    }

    private async Task DrainBatchAsync(CancellationToken ct)
    {
        await using var scope = _scopeFactory.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<CoupleDbContext>();

        var pending = await db.OutboxEvents
            .Where(e => e.DispatchedAt == null)
            .OrderBy(e => e.CreatedAt)
            .Take(BatchSize)
            .ToListAsync(ct);

        if (pending.Count == 0) return;

        foreach (var ev in pending)
        {
            // TODO Phase 3+: route by EventType to FCM / partner notifier / etc.
            ev.DispatchedAt = DateTimeOffset.UtcNow;
            ev.Attempts += 1;
        }

        await db.SaveChangesAsync(ct);
    }
}
