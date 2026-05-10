using Couple.Domain.Abstractions;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace Couple.Infrastructure.Persistence.Interceptors;

public class CoupleScopingInterceptor : SaveChangesInterceptor
{
    private readonly ICurrentUser _currentUser;

    public CoupleScopingInterceptor(ICurrentUser currentUser)
    {
        _currentUser = currentUser;
    }

    public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData eventData,
        InterceptionResult<int> result,
        CancellationToken cancellationToken = default)
    {
        var ctx = eventData.Context;
        if (ctx is null) return base.SavingChangesAsync(eventData, result, cancellationToken);

        foreach (var entry in ctx.ChangeTracker.Entries())
        {
            if (entry.Entity is not ICoupleScoped scoped) continue;
            if (entry.State == EntityState.Added)
            {
                if (scoped.CoupleId == Guid.Empty)
                {
                    if (_currentUser.CoupleId is null)
                        throw new InvalidOperationException(
                            $"Cannot persist couple-scoped entity '{entry.Metadata.Name}': caller has no active couple.");
                    scoped.CoupleId = _currentUser.CoupleId.Value;
                }
            }
            else if (entry.State == EntityState.Modified || entry.State == EntityState.Deleted)
            {
                EnsureScopeMatch(entry, scoped);
            }
        }

        return base.SavingChangesAsync(eventData, result, cancellationToken);
    }

    private void EnsureScopeMatch(EntityEntry entry, ICoupleScoped scoped)
    {
        if (_currentUser.CoupleId is null) return; // background workers (e.g. outbox dispatcher) bypass
        if (scoped.CoupleId != _currentUser.CoupleId.Value)
            throw new UnauthorizedAccessException(
                $"Couple scope mismatch on '{entry.Metadata.Name}': entity belongs to a different couple.");
    }
}
