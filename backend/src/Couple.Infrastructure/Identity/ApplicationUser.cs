using Microsoft.AspNetCore.Identity;

namespace Couple.Infrastructure.Identity;

public class ApplicationUser : IdentityUser<Guid>
{
    public string DisplayName { get; set; } = string.Empty;
    public string? AvatarUrl { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}
