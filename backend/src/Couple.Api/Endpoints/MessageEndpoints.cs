using Couple.Api.Hubs;
using Couple.Domain.Abstractions;
using Couple.Domain.Entities;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;

namespace Couple.Api.Endpoints;

public static class MessageEndpoints
{
    public record SendRequest(
        Guid Id,
        MessageType Type,
        string? Content,
        string? Payload,
        string? MediaObjectKey,
        string? MediaMimeType,
        int? MediaDurationMs,
        long? MediaSizeBytes);

    public static IEndpointRouteBuilder MapMessageEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/messages").WithTags("Messages").RequireAuthorization();

        group.MapPost("/", Send);
        group.MapGet("/", List);
        group.MapPost("/{id:guid}/read", MarkRead);

        return app;
    }

    private static async Task<IResult> Send(
        [FromBody] SendRequest req,
        IMessageService messages,
        IHubContext<ChatHub, IChatClient> hub,
        ICurrentUser current,
        CancellationToken ct)
    {
        if (current.CoupleId is null) return Results.Unauthorized();
        if (req.Id == Guid.Empty)
            return Results.BadRequest(new { error = "id_required_uuidv7" });
        if (req.Type == MessageType.Text &&
            string.IsNullOrWhiteSpace(req.Content))
            return Results.BadRequest(new { error = "content_required_for_text" });

        var saved = await messages.UpsertAsync(
            new MessageInput(
                req.Id,
                req.Type,
                req.Content,
                req.Payload,
                req.MediaObjectKey,
                req.MediaMimeType,
                req.MediaDurationMs,
                req.MediaSizeBytes),
            ct);
        var dto = MessageDto.From(saved);

        // Hub bağlantısı olmayan akışta da partner cihazına broadcast et.
        await hub.Clients
            .Group(ChatHub.GroupName(current.CoupleId.Value))
            .ReceiveMessage(dto);

        return Results.Ok(dto);
    }

    private static async Task<IResult> List(
        IMessageService messages,
        [FromQuery(Name = "since")] DateTimeOffset? since,
        [FromQuery(Name = "take")] int? take,
        CancellationToken ct)
    {
        var items = await messages.ListAsync(since, take ?? 50, ct);
        return Results.Ok(items.ConvertAll(MessageDto.From));
    }

    private static async Task<IResult> MarkRead(
        Guid id,
        IMessageService messages,
        IHubContext<ChatHub, IChatClient> hub,
        ICurrentUser current,
        CancellationToken ct)
    {
        if (current.CoupleId is null) return Results.Unauthorized();
        await messages.MarkReadAsync(id, ct);
        await hub.Clients
            .Group(ChatHub.GroupName(current.CoupleId.Value))
            .MessageRead(id, DateTimeOffset.UtcNow);
        return Results.NoContent();
    }
}
