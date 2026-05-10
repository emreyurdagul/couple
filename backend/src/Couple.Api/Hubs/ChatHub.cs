using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace Couple.Api.Hubs;

[Authorize]
public class ChatHub : Hub
{
    public override Task OnConnectedAsync() => base.OnConnectedAsync();
}
