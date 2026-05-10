using Couple.Api.Endpoints;
using Couple.Domain.Abstractions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace Couple.Api.Hubs;

[Authorize]
public class LocationHub : Hub<ILocationClient>
{
    private readonly ICurrentUser _currentUser;
    private readonly ILocationService _locations;

    public LocationHub(ICurrentUser currentUser, ILocationService locations)
    {
        _currentUser = currentUser;
        _locations = locations;
    }

    public static string GroupName(Guid coupleId) => $"couple-loc:{coupleId:D}";

    public override async Task OnConnectedAsync()
    {
        if (_currentUser.CoupleId is null)
        {
            Context.Abort();
            return;
        }
        await Groups.AddToGroupAsync(
            Context.ConnectionId,
            GroupName(_currentUser.CoupleId.Value));
        await base.OnConnectedAsync();
    }

    public async Task<LocationDto> SendLocation(SendLocationPayload payload, CancellationToken ct)
    {
        if (_currentUser.CoupleId is null)
            throw new HubException("no_active_couple");

        var input = new LocationInput(
            Latitude: payload.Latitude,
            Longitude: payload.Longitude,
            Accuracy: payload.Accuracy,
            Speed: payload.Speed,
            Heading: payload.Heading,
            BatteryLevel: payload.BatteryLevel,
            IsMoving: payload.IsMoving,
            RecordedAt: payload.RecordedAt);

        var saved = await _locations.RecordAsync(input, ct);
        var dto = LocationDtoMapper.From(saved);

        await Clients
            .OthersInGroup(GroupName(_currentUser.CoupleId.Value))
            .ReceiveLocation(dto);

        return dto;
    }
}

public record SendLocationPayload(
    double Latitude,
    double Longitude,
    double? Accuracy,
    double? Speed,
    double? Heading,
    int? BatteryLevel,
    bool IsMoving,
    DateTimeOffset RecordedAt);

public interface ILocationClient
{
    Task ReceiveLocation(LocationDto location);
}
