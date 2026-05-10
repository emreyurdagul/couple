using Couple.Api.Auth;
using Couple.Domain.Abstractions;
using Couple.Infrastructure.Identity;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;

namespace Couple.Api.Endpoints;

public static class AuthEndpoints
{
    public record RegisterRequest(string Email, string Password, string DisplayName);
    public record LoginRequest(string Email, string Password);
    public record RefreshRequest(string RefreshToken);
    public record AuthResponse(
        string AccessToken,
        DateTimeOffset AccessTokenExpiresAt,
        string RefreshToken,
        DateTimeOffset RefreshTokenExpiresAt,
        Guid UserId,
        Guid? CoupleId);

    public static IEndpointRouteBuilder MapAuthEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/auth").WithTags("Auth");

        group.MapPost("/register", Register);
        group.MapPost("/login", Login);
        group.MapPost("/refresh", Refresh);
        group.MapPost("/logout", Logout).RequireAuthorization();

        return app;
    }

    private static async Task<IResult> Register(
        [FromBody] RegisterRequest req,
        UserManager<ApplicationUser> users,
        AuthService auth,
        CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(req.Email) || string.IsNullOrWhiteSpace(req.Password))
            return Results.BadRequest(new { error = "email_and_password_required" });

        var existing = await users.FindByEmailAsync(req.Email);
        if (existing is not null)
            return Results.Conflict(new { error = "email_in_use" });

        var user = new ApplicationUser
        {
            Id = Guid.CreateVersion7(),
            UserName = req.Email,
            Email = req.Email,
            DisplayName = string.IsNullOrWhiteSpace(req.DisplayName) ? req.Email.Split('@')[0] : req.DisplayName,
            CreatedAt = DateTimeOffset.UtcNow,
        };
        var create = await users.CreateAsync(user, req.Password);
        if (!create.Succeeded)
            return Results.BadRequest(new { error = "register_failed", details = create.Errors.Select(e => e.Description) });

        var result = await auth.IssueTokensAsync(user, ct);
        return Results.Ok(ToResponse(result));
    }

    private static async Task<IResult> Login(
        [FromBody] LoginRequest req,
        UserManager<ApplicationUser> users,
        AuthService auth,
        CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(req.Email) || string.IsNullOrWhiteSpace(req.Password))
            return Results.BadRequest(new { error = "email_and_password_required" });

        var user = await users.FindByEmailAsync(req.Email);
        if (user is null)
            return Results.Unauthorized();

        var ok = await users.CheckPasswordAsync(user, req.Password);
        if (!ok)
            return Results.Unauthorized();

        var result = await auth.IssueTokensAsync(user, ct);
        return Results.Ok(ToResponse(result));
    }

    private static async Task<IResult> Refresh(
        [FromBody] RefreshRequest req,
        AuthService auth,
        CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(req.RefreshToken))
            return Results.BadRequest(new { error = "refresh_token_required" });

        var result = await auth.RefreshAsync(req.RefreshToken, ct);
        if (result is null)
            return Results.Unauthorized();

        return Results.Ok(ToResponse(result));
    }

    private static async Task<IResult> Logout(
        ICurrentUser current,
        AuthService auth,
        CancellationToken ct)
    {
        if (current.UserId is null)
            return Results.Unauthorized();
        await auth.RevokeAllAsync(current.UserId.Value, ct);
        return Results.NoContent();
    }

    private static AuthResponse ToResponse(AuthResult r) => new(
        r.AccessToken,
        r.AccessTokenExpiresAt,
        r.RefreshToken,
        r.RefreshTokenExpiresAt,
        r.UserId,
        r.CoupleId);
}
