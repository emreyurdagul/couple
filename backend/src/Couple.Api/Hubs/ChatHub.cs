using Couple.Api.Endpoints;
using Couple.Domain.Abstractions;
using Couple.Domain.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace Couple.Api.Hubs;

[Authorize]
public class ChatHub : Hub<IChatClient>
{
    private readonly ICurrentUser _currentUser;
    private readonly IMessageService _messages;

    public ChatHub(ICurrentUser currentUser, IMessageService messages)
    {
        _currentUser = currentUser;
        _messages = messages;
    }

    public static string GroupName(Guid coupleId) => $"couple:{coupleId:D}";

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

    public async Task<MessageDto> SendMessage(SendMessagePayload payload, CancellationToken ct)
    {
        if (_currentUser.CoupleId is null)
            throw new HubException("no_active_couple");

        var input = new MessageInput(
            Id: payload.Id,
            Type: payload.Type,
            Content: payload.Content,
            Payload: payload.Payload,
            MediaObjectKey: payload.MediaObjectKey,
            MediaMimeType: payload.MediaMimeType,
            MediaDurationMs: payload.MediaDurationMs,
            MediaSizeBytes: payload.MediaSizeBytes);

        var saved = await _messages.UpsertAsync(input, ct);
        var dto = MessageDto.From(saved);

        // Diğer cihazlara push et (sender'a echo etmiyoruz; çağıran return ile alır).
        await Clients
            .OthersInGroup(GroupName(_currentUser.CoupleId.Value))
            .ReceiveMessage(dto);

        return dto;
    }

    public async Task MarkRead(Guid messageId, CancellationToken ct)
    {
        if (_currentUser.CoupleId is null) return;
        await _messages.MarkReadAsync(messageId, ct);
        await Clients
            .OthersInGroup(GroupName(_currentUser.CoupleId.Value))
            .MessageRead(messageId, DateTimeOffset.UtcNow);
    }

    public Task Typing(bool isTyping)
    {
        if (_currentUser.CoupleId is null) return Task.CompletedTask;
        return Clients
            .OthersInGroup(GroupName(_currentUser.CoupleId.Value))
            .Typing(isTyping);
    }
}

public record SendMessagePayload(
    Guid Id,
    MessageType Type,
    string? Content,
    string? Payload,
    string? MediaObjectKey,
    string? MediaMimeType,
    int? MediaDurationMs,
    long? MediaSizeBytes);

public interface IChatClient
{
    Task ReceiveMessage(MessageDto message);
    Task MessageRead(Guid messageId, DateTimeOffset readAt);
    Task Typing(bool isTyping);
}
