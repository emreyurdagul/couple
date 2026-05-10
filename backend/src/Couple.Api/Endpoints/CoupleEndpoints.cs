using System.Security.Cryptography;
using Couple.Api.Auth;
using Couple.Domain.Abstractions;
using Couple.Domain.Entities;
using Couple.Infrastructure.Identity;
using Couple.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Couple.Api.Endpoints;

public static class CoupleEndpoints
{
    private static readonly TimeSpan InviteTtl = TimeSpan.FromHours(24);
    private const string CodeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // 32 chars, ambiguous-free
    private const int CodeLength = 6;

    public record CreateInviteResponse(string Code, DateTimeOffset ExpiresAt);
    public record AcceptInviteResponse(Guid CoupleId, Guid PartnerUserId, string PartnerDisplayName);
    public record CoupleInfoResponse(
        Guid CoupleId,
        string Status,
        DateTimeOffset CreatedAt,
        Guid PartnerUserId,
        string PartnerDisplayName);

    public static IEndpointRouteBuilder MapCoupleEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/couples").WithTags("Couples").RequireAuthorization();

        group.MapPost("/invites", CreateInvite);
        group.MapPost("/invites/{code}/accept", AcceptInvite);
        group.MapGet("/me", GetMyCouple);
        group.MapDelete("/me", EndMyCouple);

        return app;
    }

    private static async Task<IResult> CreateInvite(
        ICurrentUser current,
        CoupleDbContext db,
        CancellationToken ct)
    {
        if (current.UserId is null) return Results.Unauthorized();

        var hasActive = await db.Couples.IgnoreQueryFilters()
            .AnyAsync(c => (c.User1Id == current.UserId || c.User2Id == current.UserId)
                          && c.Status == CoupleStatus.Active, ct);
        if (hasActive)
            return Results.Conflict(new { error = "already_in_active_couple" });

        // Çakışma olursa birkaç kez tekrar dene
        for (var attempt = 0; attempt < 5; attempt++)
        {
            var code = GenerateCode();
            var invite = new CoupleInvite
            {
                Id = Guid.CreateVersion7(),
                FromUserId = current.UserId.Value,
                Code = code,
                ExpiresAt = DateTimeOffset.UtcNow.Add(InviteTtl),
                CreatedAt = DateTimeOffset.UtcNow,
            };
            db.CoupleInvites.Add(invite);
            try
            {
                await db.SaveChangesAsync(ct);
                return Results.Ok(new CreateInviteResponse(code, invite.ExpiresAt));
            }
            catch (DbUpdateException)
            {
                db.CoupleInvites.Remove(invite);
                // unique violation: kod çakışması, retry
            }
        }
        return Results.Problem("invite_code_generation_failed", statusCode: 500);
    }

    private static async Task<IResult> AcceptInvite(
        string code,
        ICurrentUser current,
        CoupleDbContext db,
        UserManager<ApplicationUser> users,
        AuthService auth,
        CancellationToken ct)
    {
        if (current.UserId is null) return Results.Unauthorized();

        var invite = await db.CoupleInvites
            .FirstOrDefaultAsync(i => i.Code == code.ToUpperInvariant() && i.ConsumedByUserId == null, ct);
        if (invite is null)
            return Results.NotFound(new { error = "invite_not_found_or_consumed" });
        if (invite.ExpiresAt <= DateTimeOffset.UtcNow)
            return Results.BadRequest(new { error = "invite_expired" });
        if (invite.FromUserId == current.UserId)
            return Results.BadRequest(new { error = "cannot_accept_own_invite" });

        var bothUsersFreeOfActive = !await db.Couples.IgnoreQueryFilters()
            .AnyAsync(c =>
                ((c.User1Id == invite.FromUserId || c.User2Id == invite.FromUserId)
                 || (c.User1Id == current.UserId || c.User2Id == current.UserId))
                && c.Status == CoupleStatus.Active, ct);
        if (!bothUsersFreeOfActive)
            return Results.Conflict(new { error = "one_of_users_already_in_couple" });

        var couple = new Domain.Entities.Couple
        {
            Id = Guid.CreateVersion7(),
            User1Id = invite.FromUserId,
            User2Id = current.UserId.Value,
            Status = CoupleStatus.Active,
            CreatedAt = DateTimeOffset.UtcNow,
        };
        db.Couples.Add(couple);

        invite.ConsumedByUserId = current.UserId.Value;
        invite.ConsumedAt = DateTimeOffset.UtcNow;

        await db.SaveChangesAsync(ct);

        var partner = await users.FindByIdAsync(invite.FromUserId.ToString());
        return Results.Ok(new AcceptInviteResponse(
            couple.Id,
            invite.FromUserId,
            partner?.DisplayName ?? string.Empty));
    }

    private static async Task<IResult> GetMyCouple(
        ICurrentUser current,
        CoupleDbContext db,
        UserManager<ApplicationUser> users,
        CancellationToken ct)
    {
        if (current.UserId is null) return Results.Unauthorized();

        var couple = await db.Couples.IgnoreQueryFilters()
            .Where(c => (c.User1Id == current.UserId || c.User2Id == current.UserId)
                        && c.Status == CoupleStatus.Active)
            .FirstOrDefaultAsync(ct);
        if (couple is null)
            return Results.NotFound(new { error = "no_active_couple" });

        var partnerId = couple.User1Id == current.UserId.Value ? couple.User2Id : couple.User1Id;
        var partner = await users.FindByIdAsync(partnerId.ToString());

        return Results.Ok(new CoupleInfoResponse(
            couple.Id,
            couple.Status.ToString(),
            couple.CreatedAt,
            partnerId,
            partner?.DisplayName ?? string.Empty));
    }

    private static async Task<IResult> EndMyCouple(
        ICurrentUser current,
        CoupleDbContext db,
        AuthService auth,
        CancellationToken ct)
    {
        if (current.UserId is null) return Results.Unauthorized();

        var couple = await db.Couples.IgnoreQueryFilters()
            .Where(c => (c.User1Id == current.UserId || c.User2Id == current.UserId)
                        && c.Status == CoupleStatus.Active)
            .FirstOrDefaultAsync(ct);
        if (couple is null)
            return Results.NotFound(new { error = "no_active_couple" });

        couple.Status = CoupleStatus.Ended;
        couple.EndedAt = DateTimeOffset.UtcNow;
        await db.SaveChangesAsync(ct);

        // İki tarafın access token'larındaki couple_id artık geçersiz olmalı.
        // Refresh tokenları da revoke ediyoruz; her iki kullanıcı yeniden login olur.
        await auth.RevokeAllAsync(couple.User1Id, ct);
        await auth.RevokeAllAsync(couple.User2Id, ct);

        return Results.NoContent();
    }

    private static string GenerateCode()
    {
        Span<byte> bytes = stackalloc byte[CodeLength];
        RandomNumberGenerator.Fill(bytes);
        Span<char> chars = stackalloc char[CodeLength];
        for (var i = 0; i < CodeLength; i++)
            chars[i] = CodeAlphabet[bytes[i] % CodeAlphabet.Length];
        return new string(chars);
    }
}
