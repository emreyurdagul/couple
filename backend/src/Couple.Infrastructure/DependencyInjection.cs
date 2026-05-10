using Couple.Domain.Abstractions;
using Couple.Infrastructure.Identity;
using Couple.Infrastructure.Outbox;
using Couple.Infrastructure.Persistence;
using Couple.Infrastructure.Persistence.Interceptors;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace Couple.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddCoupleInfrastructure(this IServiceCollection services, IConfiguration config)
    {
        services.AddScoped<CoupleScopingInterceptor>();

        services.AddDbContext<CoupleDbContext>((sp, options) =>
        {
            var conn = config.GetConnectionString("Default")
                ?? throw new InvalidOperationException("ConnectionStrings:Default not configured.");
            options.UseNpgsql(conn, npg => npg.UseNetTopologySuite());
            options.AddInterceptors(sp.GetRequiredService<CoupleScopingInterceptor>());
        });

        services
            .AddIdentityCore<ApplicationUser>(o =>
            {
                o.User.RequireUniqueEmail = true;
                o.Password.RequireNonAlphanumeric = false;
                o.Password.RequireUppercase = false;
                o.Password.RequiredLength = 8;
            })
            .AddRoles<IdentityRole<Guid>>()
            .AddEntityFrameworkStores<CoupleDbContext>();

        services.AddScoped<IOutboxPublisher, OutboxPublisher>();
        services.AddHostedService<OutboxDispatcher>();

        return services;
    }
}
