using Couple.Api.Hubs;
using Couple.Domain.Abstractions;
using Couple.Domain.Entities;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;

namespace Couple.Api.Endpoints;

public static class LocationDtoMapper
{
    public static LocationDto From(LocationPoint p) => new(
        p.Id,
        p.UserId,
        p.Position.Y, // latitude
        p.Position.X, // longitude
        p.Accuracy,
        p.Speed,
        p.Heading,
        p.BatteryLevel,
        p.IsMoving,
        p.RecordedAt,
        p.ReceivedAt);
}

public static class LocationEndpoints
{
    public record RecordRequest(
        double Latitude,
        double Longitude,
        double? Accuracy,
        double? Speed,
        double? Heading,
        int? BatteryLevel,
        bool IsMoving,
        DateTimeOffset RecordedAt);

    public static IEndpointRouteBuilder MapLocationEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/locations").WithTags("Locations").RequireAuthorization();

        group.MapPost("/", Record);
        group.MapPost("/batch", RecordBatch);
        group.MapGet("/current", GetPartnerCurrent);
        group.MapGet("/", List);
        group.MapGet("/together", GetTogether);

        return app;
    }

    private static async Task<IResult> Record(
        [FromBody] RecordRequest req,
        ILocationService locations,
        IHubContext<LocationHub, ILocationClient> hub,
        ICurrentUser current,
        CancellationToken ct)
    {
        if (current.CoupleId is null) return Results.Unauthorized();
        if (!IsValidCoord(req.Latitude, req.Longitude))
            return Results.BadRequest(new { error = "coordinate_out_of_range" });

        try
        {
            var saved = await locations.RecordAsync(ToInput(req), ct);
            var dto = LocationDtoMapper.From(saved);

            await hub.Clients
                .Group(LocationHub.GroupName(current.CoupleId.Value))
                .ReceiveLocation(dto);

            return Results.Ok(dto);
        }
        catch (LocationSharingDisabledException)
        {
            return Results.StatusCode(StatusCodes.Status403Forbidden);
        }
    }

    private static async Task<IResult> RecordBatch(
        [FromBody] List<RecordRequest> items,
        ILocationService locations,
        IHubContext<LocationHub, ILocationClient> hub,
        ICurrentUser current,
        CancellationToken ct)
    {
        if (current.CoupleId is null) return Results.Unauthorized();
        if (items.Count == 0) return Results.Ok(Array.Empty<LocationDto>());
        if (items.Count > 200)
            return Results.BadRequest(new { error = "batch_too_large" });
        foreach (var r in items)
        {
            if (!IsValidCoord(r.Latitude, r.Longitude))
                return Results.BadRequest(new { error = "coordinate_out_of_range" });
        }

        try
        {
            var saved = await locations.RecordBatchAsync(items.ConvertAll(ToInput), ct);
            var dtos = saved.ConvertAll(LocationDtoMapper.From);

            // Yalnız son noktayı broadcast et — batch tipik olarak gecikmiş; canlı imleci güncelle.
            if (dtos.Count > 0)
            {
                await hub.Clients
                    .Group(LocationHub.GroupName(current.CoupleId.Value))
                    .ReceiveLocation(dtos[^1]);
            }
            return Results.Ok(dtos);
        }
        catch (LocationSharingDisabledException)
        {
            return Results.StatusCode(StatusCodes.Status403Forbidden);
        }
    }

    private static async Task<IResult> GetPartnerCurrent(
        ILocationService locations,
        ICurrentUser current,
        CancellationToken ct)
    {
        if (current.CoupleId is null) return Results.Unauthorized();
        var dto = await locations.GetPartnerCurrentAsync(ct);
        return dto is null ? Results.NoContent() : Results.Ok(dto);
    }

    private static async Task<IResult> List(
        ILocationService locations,
        [FromQuery(Name = "from")] DateTimeOffset from,
        [FromQuery(Name = "to")] DateTimeOffset to,
        [FromQuery(Name = "take")] int? take,
        CancellationToken ct)
    {
        var rows = await locations.ListAsync(from, to, take ?? 1000, ct);
        return Results.Ok(rows);
    }

    private static async Task<IResult> GetTogether(
        ILocationService locations,
        [FromQuery(Name = "from")] DateTimeOffset from,
        [FromQuery(Name = "to")] DateTimeOffset to,
        CancellationToken ct)
    {
        var summary = await locations.GetTogetherSummaryAsync(from, to, ct);
        return Results.Ok(summary);
    }

    private static LocationInput ToInput(RecordRequest r) => new(
        r.Latitude, r.Longitude, r.Accuracy, r.Speed, r.Heading,
        r.BatteryLevel, r.IsMoving, r.RecordedAt);

    private static bool IsValidCoord(double lat, double lng) =>
        lat is >= -90 and <= 90 && lng is >= -180 and <= 180;
}
