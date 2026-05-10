using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Couple.Infrastructure.Identity;
using Microsoft.IdentityModel.Tokens;

namespace Couple.Api.Auth;

public class JwtOptions
{
    public string Issuer { get; set; } = "couple-api";
    public string Audience { get; set; } = "couple-app";
    public string Secret { get; set; } = string.Empty;
    public int AccessTokenMinutes { get; set; } = 60;
    public int RefreshTokenDays { get; set; } = 30;
}

public class JwtTokenService
{
    private readonly JwtOptions _opts;

    public JwtTokenService(JwtOptions opts)
    {
        _opts = opts;
    }

    public (string token, DateTimeOffset expiresAt) CreateAccessToken(ApplicationUser user, Guid? coupleId)
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new(JwtRegisteredClaimNames.Email, user.Email ?? string.Empty),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
        };
        if (coupleId is { } cid)
            claims.Add(new Claim(CurrentUser.CoupleIdClaim, cid.ToString()));

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_opts.Secret));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var expires = DateTimeOffset.UtcNow.AddMinutes(_opts.AccessTokenMinutes);
        var token = new JwtSecurityToken(
            issuer: _opts.Issuer,
            audience: _opts.Audience,
            claims: claims,
            expires: expires.UtcDateTime,
            signingCredentials: creds);
        return (new JwtSecurityTokenHandler().WriteToken(token), expires);
    }
}
