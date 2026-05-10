using Couple.Domain.Entities;

namespace Couple.Domain.Abstractions;

public record LocationInput(
    double Latitude,
    double Longitude,
    double? Accuracy,
    double? Speed,
    double? Heading,
    int? BatteryLevel,
    bool IsMoving,
    DateTimeOffset RecordedAt);

public record LocationDto(
    Guid Id,
    Guid UserId,
    double Latitude,
    double Longitude,
    double? Accuracy,
    double? Speed,
    double? Heading,
    int? BatteryLevel,
    bool IsMoving,
    DateTimeOffset RecordedAt,
    DateTimeOffset ReceivedAt);

public record TogetherDay(DateOnly Date, int TogetherMinutes);

public record TogetherSummary(
    DateTimeOffset From,
    DateTimeOffset To,
    int TotalMinutes,
    List<TogetherDay> ByDay);

public class LocationSharingDisabledException : Exception
{
    public LocationSharingDisabledException() : base("location_sharing_disabled") { }
}

public interface ILocationService
{
    /// <summary>
    /// Tek bir konum noktasını kaydeder. Couple ve user scope <see cref="ICurrentUser"/>'dan gelir.
    /// </summary>
    Task<LocationPoint> RecordAsync(LocationInput input, CancellationToken ct = default);

    /// <summary>
    /// Birden çok noktayı tek seferde kaydeder (background batch). Bağlı listeyi döner.
    /// </summary>
    Task<List<LocationPoint>> RecordBatchAsync(IReadOnlyList<LocationInput> inputs, CancellationToken ct = default);

    /// <summary>
    /// Partner'ın son bilinen konumunu döner. Henüz nokta yoksa null.
    /// </summary>
    Task<LocationDto?> GetPartnerCurrentAsync(CancellationToken ct = default);

    /// <summary>
    /// Couple'ın history'sini döner; her iki kullanıcının noktaları kronolojik artan.
    /// <paramref name="from"/> dahil, <paramref name="to"/> dahil.
    /// </summary>
    Task<List<LocationDto>> ListAsync(DateTimeOffset from, DateTimeOffset to, int maxPoints, CancellationToken ct = default);

    /// <summary>
    /// Belirli aralıkta gün bazlı beraber-süre özeti döner. Bugünü kapsıyorsa lazy compute,
    /// geçmiş günler <see cref="DailyTogetherSummary"/> tablosundan okunur.
    /// </summary>
    Task<TogetherSummary> GetTogetherSummaryAsync(DateTimeOffset from, DateTimeOffset to, CancellationToken ct = default);
}
