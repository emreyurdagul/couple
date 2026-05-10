namespace Couple.Infrastructure.Outbox;

public interface IOutboxPublisher
{
    Task EnqueueAsync(string aggregateType, string aggregateId, string eventType, object payload, CancellationToken ct = default);
}
