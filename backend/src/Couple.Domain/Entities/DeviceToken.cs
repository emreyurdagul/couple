namespace Couple.Domain.Entities;

public enum DevicePlatform
{
    Android = 0,
    iOS = 1,
}

public class DeviceToken
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public DevicePlatform Platform { get; set; }
    public string FcmToken { get; set; } = string.Empty;
    public DateTimeOffset UpdatedAt { get; set; }
}
