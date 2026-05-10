using System.Text;
using Couple.Api.Auth;
using Couple.Api.Endpoints;
using Couple.Api.Hubs;
using Couple.Domain.Abstractions;
using Couple.Infrastructure;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, cfg) => cfg.ReadFrom.Configuration(ctx.Configuration).WriteTo.Console());

builder.Services.AddOpenApi();
builder.Services.AddHttpContextAccessor();
builder.Services.AddCoupleInfrastructure(builder.Configuration);
builder.Services.AddScoped<ICurrentUser, CurrentUser>();

var jwtOpts = builder.Configuration.GetSection("Jwt").Get<JwtOptions>() ?? new JwtOptions();
if (string.IsNullOrWhiteSpace(jwtOpts.Secret))
{
    if (builder.Environment.IsDevelopment())
        jwtOpts.Secret = "dev-only-secret-change-me-pleeeeeeeeeeeease-32+chars";
    else
        throw new InvalidOperationException("Jwt:Secret must be configured.");
}
builder.Services.AddSingleton(jwtOpts);
builder.Services.AddSingleton<JwtTokenService>();
builder.Services.AddScoped<AuthService>();

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtOpts.Issuer,
            ValidAudience = jwtOpts.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOpts.Secret)),
            ClockSkew = TimeSpan.FromSeconds(30),
        };
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = ctx =>
            {
                var accessToken = ctx.Request.Query["access_token"];
                var path = ctx.HttpContext.Request.Path;
                if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hubs"))
                    ctx.Token = accessToken;
                return Task.CompletedTask;
            }
        };
    });

builder.Services.AddAuthorization();
builder.Services.AddSignalR();

builder.Services.AddHealthChecks()
    .AddNpgSql(
        sp => builder.Configuration.GetConnectionString("Default") ?? string.Empty,
        name: "postgres",
        tags: new[] { "ready" });

var app = builder.Build();

app.UseSerilogRequestLogging();

if (app.Environment.IsDevelopment())
    app.MapOpenApi();

app.UseAuthentication();
app.UseAuthorization();

app.MapHealthChecks("/health/live", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
{
    Predicate = _ => false,
});
app.MapHealthChecks("/health/ready", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
{
    Predicate = r => r.Tags.Contains("ready"),
});

app.MapGet("/", () => Results.Ok(new { name = "Couple API", version = "0.1.0" }));

app.MapAuthEndpoints();
app.MapCoupleEndpoints();
app.MapMessageEndpoints();
app.MapLocationEndpoints();

app.MapHub<ChatHub>("/hubs/chat");
app.MapHub<LocationHub>("/hubs/location");

app.Run();

public partial class Program;
