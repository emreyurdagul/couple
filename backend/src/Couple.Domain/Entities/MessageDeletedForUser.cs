using Couple.Domain.Abstractions;

namespace Couple.Domain.Entities;

/// <summary>
/// "for me" silme — sadece bu kullanıcıdan gizli, partner görür.
/// "for both" silme Messages.DeletedAt + DeletedByUserId'ye düşer.
/// </summary>
public class MessageDeletedForUser : ICoupleScoped
{
    public Guid Id { get; set; }
    public Guid CoupleId { get; set; }
    public Guid MessageId { get; set; }
    public Guid UserId { get; set; }
    public DateTimeOffset DeletedAt { get; set; }
}
