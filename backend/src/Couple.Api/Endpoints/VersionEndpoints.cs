using System.Security.Cryptography;
using Couple.Domain.Entities;
using Couple.Infrastructure.Persistence;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Couple.Api.Endpoints;

public static class VersionEndpoints
{
    public record VersionInfoResponse(
        bool UpdateAvailable,
        bool Mandatory,
        int LatestVersionCode,
        string LatestVersionName,
        string DownloadUrl,
        long SizeBytes,
        string Sha256,
        string? ReleaseNotes);

    public record UploadResponse(
        Guid Id,
        string Platform,
        int VersionCode,
        string VersionName,
        string FileName,
        long SizeBytes);

    public static IEndpointRouteBuilder MapVersionEndpoints(this IEndpointRouteBuilder app)
    {
        var pub = app.MapGroup("/api/version").WithTags("Version");
        pub.MapGet("/latest", GetLatest);

        var admin = app.MapGroup("/api/admin/versions").WithTags("VersionAdmin");
        admin.MapPost("", Upload).DisableAntiforgery();

        return app;
    }

    private static async Task<IResult> GetLatest(
        [FromQuery] string? platform,
        [FromQuery(Name = "currentVersionCode")] int? currentVersionCode,
        CoupleDbContext db,
        HttpContext http,
        CancellationToken ct)
    {
        var plat = string.IsNullOrWhiteSpace(platform) ? "android" : platform.ToLowerInvariant();

        var latest = await db.AppVersions
            .AsNoTracking()
            .Where(v => v.Platform == plat)
            .OrderByDescending(v => v.VersionCode)
            .FirstOrDefaultAsync(ct);

        if (latest is null)
            return Results.NotFound(new { error = "no_versions" });

        var current = currentVersionCode ?? 0;
        var updateAvailable = latest.VersionCode > current;
        var mandatory = current > 0 && current < latest.MinSupportedVersionCode;

        var req = http.Request;
        var origin = $"{req.Scheme}://{req.Host}";
        var downloadUrl = $"{origin}/downloads/{Uri.EscapeDataString(latest.FileName)}";

        return Results.Ok(new VersionInfoResponse(
            updateAvailable,
            mandatory,
            latest.VersionCode,
            latest.VersionName,
            downloadUrl,
            latest.SizeBytes,
            latest.Sha256,
            latest.ReleaseNotes));
    }

    private static async Task<IResult> Upload(
        HttpRequest request,
        CoupleDbContext db,
        IConfiguration config,
        IWebHostEnvironment env,
        CancellationToken ct)
    {
        var expected = config["Admin:Token"];
        if (string.IsNullOrWhiteSpace(expected))
            return Results.Problem("admin_token_not_configured", statusCode: 500);

        if (!request.Headers.TryGetValue("X-Admin-Token", out var provided)
            || !CryptographicOperations.FixedTimeEquals(
                System.Text.Encoding.UTF8.GetBytes(provided.ToString()),
                System.Text.Encoding.UTF8.GetBytes(expected)))
            return Results.Unauthorized();

        if (!request.HasFormContentType)
            return Results.BadRequest(new { error = "multipart_required" });

        var form = await request.ReadFormAsync(ct);
        var platform = (form["platform"].FirstOrDefault() ?? "android").ToLowerInvariant();
        if (!int.TryParse(form["versionCode"], out var versionCode))
            return Results.BadRequest(new { error = "versionCode_required" });
        var versionName = form["versionName"].FirstOrDefault();
        if (string.IsNullOrWhiteSpace(versionName))
            return Results.BadRequest(new { error = "versionName_required" });
        _ = int.TryParse(form["minSupportedVersionCode"], out var minSupported);
        var releaseNotes = form["releaseNotes"].FirstOrDefault();

        var file = form.Files.GetFile("file");
        if (file is null || file.Length == 0)
            return Results.BadRequest(new { error = "file_required" });

        var uploadsRoot = config["Storage:UploadsPath"]
            ?? Path.Combine(env.ContentRootPath, "uploads");
        var apksDir = Path.Combine(uploadsRoot, "apks");
        Directory.CreateDirectory(apksDir);

        var safeBase = $"{platform}-{versionCode}-{Guid.NewGuid():N}";
        var ext = Path.GetExtension(file.FileName);
        if (string.IsNullOrWhiteSpace(ext)) ext = ".apk";
        var fileName = safeBase + ext;
        var filePath = Path.Combine(apksDir, fileName);

        string sha256;
        await using (var fs = File.Create(filePath))
        await using (var src = file.OpenReadStream())
        {
            using var sha = SHA256.Create();
            var buffer = new byte[81920];
            int read;
            while ((read = await src.ReadAsync(buffer, ct)) > 0)
            {
                sha.TransformBlock(buffer, 0, read, null, 0);
                await fs.WriteAsync(buffer.AsMemory(0, read), ct);
            }
            sha.TransformFinalBlock(Array.Empty<byte>(), 0, 0);
            sha256 = Convert.ToHexString(sha.Hash!).ToLowerInvariant();
        }

        var size = new FileInfo(filePath).Length;

        var existing = await db.AppVersions
            .FirstOrDefaultAsync(v => v.Platform == platform && v.VersionCode == versionCode, ct);
        if (existing is not null)
        {
            var oldPath = Path.Combine(apksDir, existing.FileName);
            if (File.Exists(oldPath)) File.Delete(oldPath);
            existing.FileName = fileName;
            existing.SizeBytes = size;
            existing.Sha256 = sha256;
            existing.VersionName = versionName!;
            existing.MinSupportedVersionCode = minSupported;
            existing.ReleaseNotes = releaseNotes;
            await db.SaveChangesAsync(ct);
            return Results.Ok(new UploadResponse(existing.Id, existing.Platform,
                existing.VersionCode, existing.VersionName, existing.FileName, existing.SizeBytes));
        }

        var entity = new AppVersion
        {
            Id = Guid.CreateVersion7(),
            Platform = platform,
            VersionCode = versionCode,
            VersionName = versionName!,
            FileName = fileName,
            SizeBytes = size,
            Sha256 = sha256,
            MinSupportedVersionCode = minSupported,
            ReleaseNotes = releaseNotes,
            CreatedAt = DateTime.UtcNow,
        };
        db.AppVersions.Add(entity);
        await db.SaveChangesAsync(ct);

        return Results.Created($"/api/admin/versions/{entity.Id}",
            new UploadResponse(entity.Id, entity.Platform, entity.VersionCode,
                entity.VersionName, entity.FileName, entity.SizeBytes));
    }
}
