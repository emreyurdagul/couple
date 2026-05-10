using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Couple.Infrastructure.Persistence;

public class DesignTimeDbContextFactory : IDesignTimeDbContextFactory<CoupleDbContext>
{
    public CoupleDbContext CreateDbContext(string[] args)
    {
        var connectionString = Environment.GetEnvironmentVariable("COUPLE_DB_CONNECTION")
            ?? "Host=localhost;Port=5432;Database=couple_dev;Username=postgres;Password=postgres";

        var options = new DbContextOptionsBuilder<CoupleDbContext>()
            .UseNpgsql(connectionString, o => o.UseNetTopologySuite())
            .Options;

        return new CoupleDbContext(options);
    }
}
