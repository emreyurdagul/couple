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
        long? MediaSizeBytes,
        Guid? ReplyToMessageId);

    public record EditRequest(string Content);

    public record ReactRequest(string Emoji);

    public static IEndpointRouteBuilder MapMessageEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/messages").WithTags("Messages").RequireAuthorization();

        group.MapPost("/", Send);
        group.MapGet("/", List);
        group.MapPost("/{id:guid}/read", MarkRead);

        // 3.2
        group.MapPatch("/{id:guid}", Edit);
        group.MapDelete("/{id:guid}", Delete);
        group.MapPost("/{id:guid}/reactions", AddReaction);
        group.MapDelete("/{id:guid}/reactions/{emoji}", RemoveReaction);

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

        try
        {
            var saved = await messages.UpsertAsync(
                new MessageInput(
                    req.Id,
                    req.Type,
                    req.Content,
                    req.Payload,
                    req.MediaObjectKey,
                    req.MediaMimeType,
                    req.MediaDurationMs,
                    req.MediaSizeBytes,
                    req.ReplyToMessageId),
                ct);
            var dto = MessageDto.From(saved);

            await hub.Clients
                .Group(ChatHub.GroupName(current.CoupleId.Value))
                .ReceiveMessage(dto);

            return Results.Ok(dto);
        }
        catch (MessageNotFoundException)
        {
            return Results.BadRequest(new { error = "reply_target_not_found" });
        }
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

    private static async Task<IResult> Edit(
        Guid id,
        [FromBody] EditRequest req,
        IMessageService messages,
        IHubContext<ChatHub, IChatClient> hub,
        ICurrentUser current,
        CancellationToken ct)
    {
        if (current.CoupleId is null) return Results.Unauthorized();
        if (string.IsNullOrWhiteSpace(req.Content))
            return Results.BadRequest(new { error = "content_required" });

        try
        {
            var updated = await messages.EditAsync(id, req.Content, ct);
            var withReactions = await messages.GetAsync(id, ct);
            var dto = withReactions is not null
                ? MessageDto.From(withReactions)
                : MessageDto.From(updated);

            await hub.Clients
                .Group(ChatHub.GroupName(current.CoupleId.Value))
                .MessageEdited(dto);

            return Results.Ok(dto);
        }
        catch (MessageNotFoundException)
        {
            return Results.NotFound(new { error = "message_not_found" });
        }
        catch (NotMessageSenderException)
        {
            return Results.StatusCode(StatusCodes.Status403Forbidden);
        }
        catch (EditWindowExpiredException)
        {
            return Results.BadRequest(new { error = "edit_window_expired" });
        }
        catch (InvalidOperationException ex)
        {
            return Results.BadRequest(new { error = ex.Message });
        }
        catch (ArgumentException ex)
        {
            return Results.BadRequest(new { error = ex.Message });
        }
    }

    private static async Task<IResult> Delete(
        Guid id,
        IMessageService messages,
        IHubContext<ChatHub, IChatClient> hub,
        ICurrentUser current,
        [FromQuery(Name = "scope")] string? scopeStr,
        CancellationToken ct)
    {
        if (current.CoupleId is null) return Results.Unauthorized();
        var scope = scopeStr?.ToLowerInvariant() switch
        {
            "both" => DeleteScope.ForBoth,
            "me" or null or "" => DeleteScope.ForMe,
            _ => (DeleteScope?)null,
        };
        if (scope is null)
            return Results.BadRequest(new { error = "scope_invalid" });

        try
        {
            await messages.DeleteAsync(id, scope.Value, ct);
            // ForBoth → her iki tarafta görünmesin diye broadcast.
            // ForMe → yalnız çağıran kullanıcı için, broadcast yapma.
            if (scope == DeleteScope.ForBoth)
            {
                await hub.Clients
                    .Group(ChatHub.GroupName(current.CoupleId.Value))
                    .MessageDeleted(id, "both");
            }
            return Results.NoContent();
        }
        catch (MessageNotFoundException)
        {
            return Results.NotFound(new { error = "message_not_found" });
        }
        catch (NotMessageSenderException)
        {
            return Results.StatusCode(StatusCodes.Status403Forbidden);
        }
    }

    private static async Task<IResult> AddReaction(
        Guid id,
        [FromBody] ReactRequest req,
        IMessageService messages,
        IHubContext<ChatHub, IChatClient> hub,
        ICurrentUser current,
        CancellationToken ct)
    {
        if (current.CoupleId is null) return Results.Unauthorized();
        try
        {
            var reaction = await messages.AddReactionAsync(id, req.Emoji, ct);
            var dto = ReactionDto.From(reaction);
            await hub.Clients
                .Group(ChatHub.GroupName(current.CoupleId.Value))
                .MessageReacted(id, dto);
            return Results.Ok(dto);
        }
        catch (MessageNotFoundException)
        {
            return Results.NotFound(new { error = "message_not_found" });
        }
        catch (ArgumentException ex)
        {
            return Results.BadRequest(new { error = ex.Message });
        }
    }

    private static async Task<IResult> RemoveReaction(
        Guid id,
        string emoji,
        IMessageService messages,
        IHubContext<ChatHub, IChatClient> hub,
        ICurrentUser current,
        CancellationToken ct)
    {
        if (current.CoupleId is null) return Results.Unauthorized();
        var decoded = Uri.UnescapeDataString(emoji);
        await messages.RemoveReactionAsync(id, decoded, ct);
        await hub.Clients
            .Group(ChatHub.GroupName(current.CoupleId.Value))
            .MessageReactionRemoved(id, current.UserId!.Value, decoded);
        return Results.NoContent();
    }
}
