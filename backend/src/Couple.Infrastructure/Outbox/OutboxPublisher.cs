using System.Text.Json;
using Couple.Domain.Entities;
using Couple.Infrastructure.Persistence;

namespace Couple.Infrastructure.Outbox;

public class OutboxPublisher : IOutboxPublisher
{
    private readonly CoupleDbContext _db;

    public OutboxPublisher(CoupleDbContext db)
    {
        _db = db;
    }

    public Task EnqueueAsync(string aggregateType, string aggregateId, string eventType, object payload, CancellationToken ct = default)
    {
        var ev = new OutboxEvent
        {
            Id = Guid.CreateVersion7(),
            AggregateType = aggregateType,
            AggregateId = aggregateId,
            EventType = eventType,
            Payload = JsonSerializer.Serialize(payload),
            CreatedAt = DateTimeOffset.UtcNow,
        };
        _db.OutboxEvents.Add(ev);
        return Task.CompletedTask;
    }
}
