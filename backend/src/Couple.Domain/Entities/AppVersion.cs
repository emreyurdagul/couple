namespace Couple.Domain.Entities;

public class AppVersion
{
    public Guid Id { get; set; }
    public string Platform { get; set; } = "android";
    public int VersionCode { get; set; }
    public string VersionName { get; set; } = "";
    public string FileName { get; set; } = "";
    public long SizeBytes { get; set; }
    public string Sha256 { get; set; } = "";
    public int MinSupportedVersionCode { get; set; }
    public string? ReleaseNotes { get; set; }
    public DateTime CreatedAt { get; set; }
}
