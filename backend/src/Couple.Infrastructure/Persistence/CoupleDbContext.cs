using Couple.Domain.Abstractions;
using Couple.Domain.Entities;
using Couple.Infrastructure.Identity;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace Couple.Infrastructure.Persistence;

public class CoupleDbContext : IdentityDbContext<ApplicationUser, IdentityRole<Guid>, Guid>
{
    private readonly ICurrentUser? _currentUser;

    public CoupleDbContext(DbContextOptions<CoupleDbContext> options, ICurrentUser? currentUser = null)
        : base(options)
    {
        _currentUser = currentUser;
    }

    public DbSet<Domain.Entities.Couple> Couples => Set<Domain.Entities.Couple>();
    public DbSet<CoupleInvite> CoupleInvites => Set<CoupleInvite>();
    public DbSet<Message> Messages => Set<Message>();
    public DbSet<LocationPoint> LocationPoints => Set<LocationPoint>();
    public DbSet<DeviceToken> DeviceTokens => Set<DeviceToken>();
    public DbSet<OutboxEvent> OutboxEvents => Set<OutboxEvent>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        base.OnModelCreating(b);

        b.HasPostgresExtension("postgis");

        b.Entity<Domain.Entities.Couple>(e =>
        {
            e.HasKey(x => x.Id);
            e.HasIndex(x => new { x.User1Id, x.User2Id }).IsUnique();
            e.Property(x => x.Status).HasConversion<int>();
        });

        b.Entity<CoupleInvite>(e =>
        {
            e.HasKey(x => x.Id);
            e.Property(x => x.Code).HasMaxLength(12).IsRequired();
            e.HasIndex(x => x.Code)
                .IsUnique()
                .HasFilter("\"ConsumedByUserId\" IS NULL");
        });

        b.Entity<Message>(e =>
        {
            e.HasKey(x => x.Id);
            e.Property(x => x.Type).HasConversion<int>();
            e.Property(x => x.Content).HasMaxLength(4000);
            e.Property(x => x.Payload).HasColumnType("jsonb");
            e.HasIndex(x => new { x.CoupleId, x.CreatedAt });
            e.HasIndex(x => new { x.CoupleId, x.ServerReceivedAt });
            ApplyCoupleScopeFilter<Message>(e);
        });

        b.Entity<LocationPoint>(e =>
        {
            e.HasKey(x => x.Id);
            e.Property(x => x.Position).HasColumnType("geography (Point, 4326)");
            e.HasIndex(x => new { x.UserId, x.RecordedAt });
            e.HasIndex(x => new { x.CoupleId, x.ReceivedAt });
            e.HasIndex(x => x.Position).HasMethod("GIST");
            ApplyCoupleScopeFilter<LocationPoint>(e);
        });

        b.Entity<DeviceToken>(e =>
        {
            e.HasKey(x => x.Id);
            e.Property(x => x.Platform).HasConversion<int>();
            e.HasIndex(x => x.UserId);
        });

        b.Entity<OutboxEvent>(e =>
        {
            e.HasKey(x => x.Id);
            e.Property(x => x.Payload).HasColumnType("jsonb");
            e.HasIndex(x => x.DispatchedAt);
        });

        b.Entity<RefreshToken>(e =>
        {
            e.HasKey(x => x.Id);
            e.Property(x => x.TokenHash).HasMaxLength(128).IsRequired();
            e.HasIndex(x => x.TokenHash).IsUnique();
            e.HasIndex(x => x.UserId);
        });
    }

    private void ApplyCoupleScopeFilter<TEntity>(Microsoft.EntityFrameworkCore.Metadata.Builders.EntityTypeBuilder<TEntity> e)
        where TEntity : class, ICoupleScoped
    {
        e.HasQueryFilter(x => _currentUser == null
            || _currentUser.CoupleId == null
            || x.CoupleId == _currentUser.CoupleId);
    }
}
