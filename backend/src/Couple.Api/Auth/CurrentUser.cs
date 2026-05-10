using System.Security.Claims;
using Couple.Domain.Abstractions;

namespace Couple.Api.Auth;

public class CurrentUser : ICurrentUser
{
    public const string CoupleIdClaim = "couple_id";

    public Guid? UserId { get; }
    public Guid? CoupleId { get; }
    public bool IsAuthenticated { get; }

    public CurrentUser(IHttpContextAccessor accessor)
    {
        var principal = accessor.HttpContext?.User;
        IsAuthenticated = principal?.Identity?.IsAuthenticated == true;
        if (!IsAuthenticated || principal is null) return;

        if (Guid.TryParse(principal.FindFirstValue(ClaimTypes.NameIdentifier), out var uid))
            UserId = uid;
        if (Guid.TryParse(principal.FindFirstValue(CoupleIdClaim), out var cid))
            CoupleId = cid;
    }
}
