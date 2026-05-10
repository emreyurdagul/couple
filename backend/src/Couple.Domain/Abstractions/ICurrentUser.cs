namespace Couple.Domain.Abstractions;

public interface ICurrentUser
{
    Guid? UserId { get; }
    Guid? CoupleId { get; }
    bool IsAuthenticated { get; }
}
