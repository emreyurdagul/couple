using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace Couple.Api.Hubs;

[Authorize]
public class LocationHub : Hub
{
    public override Task OnConnectedAsync() => base.OnConnectedAsync();
}
