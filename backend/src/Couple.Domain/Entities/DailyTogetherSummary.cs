using Couple.Domain.Abstractions;

namespace Couple.Domain.Entities;

public class DailyTogetherSummary : ICoupleScoped
{
    public Guid Id { get; set; }
    public Guid CoupleId { get; set; }

    public DateOnly Date { get; set; }

    public int TogetherMinutes { get; set; }

    public DateTimeOffset? FirstTogetherAt { get; set; }
    public DateTimeOffset? LastTogetherAt { get; set; }

    public DateTimeOffset ComputedAt { get; set; }
}
