using System.Security.Cryptography;
using Couple.Domain.Entities;
using Couple.Infrastructure.Identity;
using Couple.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace Couple.Api.Auth;

public record AuthResult(
    Guid UserId,
    string AccessToken,
    DateTimeOffset AccessTokenExpiresAt,
    string RefreshToken,
    DateTimeOffset RefreshTokenExpiresAt,
    Guid? CoupleId);

public class AuthService
{
    private readonly UserManager<ApplicationUser> _users;
    private readonly CoupleDbContext _db;
    private readonly JwtTokenService _jwt;
    private readonly JwtOptions _jwtOpts;

    public AuthService(
        UserManager<ApplicationUser> users,
        CoupleDbContext db,
        JwtTokenService jwt,
        JwtOptions jwtOpts)
    {
        _users = users;
        _db = db;
        _jwt = jwt;
        _jwtOpts = jwtOpts;
    }

    public async Task<AuthResult> IssueTokensAsync(ApplicationUser user, CancellationToken ct = default)
    {
        var coupleId = await GetActiveCoupleIdAsync(user.Id, ct);
        var (accessToken, accessExp) = _jwt.CreateAccessToken(user, coupleId);
        var (refreshRaw, refreshHash) = GenerateRefreshToken();
        var refreshExp = DateTimeOffset.UtcNow.AddDays(_jwtOpts.RefreshTokenDays);

        _db.RefreshTokens.Add(new RefreshToken
        {
            Id = Guid.CreateVersion7(),
            UserId = user.Id,
            TokenHash = refreshHash,
            ExpiresAt = refreshExp,
            CreatedAt = DateTimeOffset.UtcNow,
        });
        await _db.SaveChangesAsync(ct);

        return new AuthResult(user.Id, accessToken, accessExp, refreshRaw, refreshExp, coupleId);
    }

    public async Task<AuthResult?> RefreshAsync(string presentedToken, CancellationToken ct = default)
    {
        var hash = HashRefreshToken(presentedToken);
        var record = await _db.RefreshTokens
            .FirstOrDefaultAsync(t => t.TokenHash == hash, ct);

        if (record is null) return null;
        if (record.RevokedAt is not null) return null;
        if (record.ExpiresAt <= DateTimeOffset.UtcNow) return null;

        var user = await _users.FindByIdAsync(record.UserId.ToString());
        if (user is null) return null;

        // Rotate
        var (newRaw, newHash) = GenerateRefreshToken();
        var newExp = DateTimeOffset.UtcNow.AddDays(_jwtOpts.RefreshTokenDays);
        var newRecord = new RefreshToken
        {
            Id = Guid.CreateVersion7(),
            UserId = user.Id,
            TokenHash = newHash,
            ExpiresAt = newExp,
            CreatedAt = DateTimeOffset.UtcNow,
        };
        record.RevokedAt = DateTimeOffset.UtcNow;
        record.ReplacedByTokenId = newRecord.Id;
        _db.RefreshTokens.Add(newRecord);

        var coupleId = await GetActiveCoupleIdAsync(user.Id, ct);
        var (accessToken, accessExp) = _jwt.CreateAccessToken(user, coupleId);

        await _db.SaveChangesAsync(ct);

        return new AuthResult(user.Id, accessToken, accessExp, newRaw, newExp, coupleId);
    }

    public async Task RevokeAllAsync(Guid userId, CancellationToken ct = default)
    {
        var now = DateTimeOffset.UtcNow;
        await _db.RefreshTokens
            .Where(t => t.UserId == userId && t.RevokedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAt, now), ct);
    }

    private async Task<Guid?> GetActiveCoupleIdAsync(Guid userId, CancellationToken ct)
    {
        var couple = await _db.Couples
            .Where(c => (c.User1Id == userId || c.User2Id == userId) && c.Status == CoupleStatus.Active)
            .Select(c => c.Id)
            .FirstOrDefaultAsync(ct);
        return couple == Guid.Empty ? null : couple;
    }

    private static (string raw, string hash) GenerateRefreshToken()
    {
        var bytes = RandomNumberGenerator.GetBytes(48);
        var raw = Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        var hash = HashRefreshToken(raw);
        return (raw, hash);
    }

    private static string HashRefreshToken(string raw)
    {
        var bytes = System.Text.Encoding.UTF8.GetBytes(raw);
        var hash = SHA256.HashData(bytes);
        return Convert.ToHexString(hash);
    }
}
