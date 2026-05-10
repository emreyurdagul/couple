# ADR-0002: Couple-scoped multi-tenancy stratejisi

**Status:** Accepted
**Tarih:** 2026-05-10

## Context

Verinin büyük bölümü (chat, konum, takvim, oyun state) **iki kullanıcılı bir çiftin** ortak alanında yaşar. Yanlışlıkla başka bir çiftin verisinin bir kullanıcıya sızması kabul edilemez (privacy + güven).

Kullanıcı açıkça: "verilerin büyük bir bütünü couple bağımlı olacak" → mimaride birinci sınıf vatandaş olmalı.

## Decision

Tüm couple'a ait entityler `ICoupleScoped { Guid CoupleId }` interface'ini implement eder. EF Core seviyesinde **iki katmanlı koruma**:

1. **Okuma:** `CoupleDbContext.OnModelCreating` her `ICoupleScoped` entity için global query filter:
   ```csharp
   x => _currentUser == null
        || _currentUser.CoupleId == null
        || x.CoupleId == _currentUser.CoupleId
   ```
   `null` user (background worker, migration) filtreyi by-pass eder; auth'lı request akışında otomatik filtrelenir.

2. **Yazma:** `CoupleScopingInterceptor : SaveChangesInterceptor`:
   - `EntityState.Added` + `CoupleId == Guid.Empty` → `_currentUser.CoupleId` ile auto-set (yoksa hata).
   - `Modified/Deleted` → entity `CoupleId` ile current user mismatch → `UnauthorizedAccessException`.

`couple_id` JWT claim'ine konur; eşleşme tamamlandığında token yenilenir, bittiğinde tekrar yenilenir.

## Consequences

- ➕ Endpoint kodu yazarken filtre eklemeyi unutmak → otomatik filtre devreye girer; insan hatası yüzeyi minimum.
- ➕ Yazma tarafında "yanlış couple'a sızıntı" da bloklanır (defense in depth).
- ➕ Yeni couple-scoped entity eklemek yalnızca `ICoupleScoped` implement etmek + filtre çağırmak; tek satırlık ekleme.
- ➖ Background worker ve admin senaryolarında filtreyi by-pass etmek için ayrı `ICurrentUser` impl veya `IgnoreQueryFilters()` çağrısı gerekir.
- ➖ Test edilmesi şart: auth'sız request'te filtre çalışmaz (zaten `[Authorize]` ile koruyoruz ama yine de explicit integration testi).
- 🔁 Sonradan Row-Level Security (RLS) PostgreSQL seviyesine taşımak istersek, EF filtreleri kaldırılır; ama bu MVP için aşırı.

## Alternatives considered

- **Endpoint başına manuel filtre**: kolay unutulur, sızıntı riski yüksek.
- **Row-Level Security (RLS)** Postgres düzeyinde: en güçlü garanti ama EF entegrasyonu daha karmaşık + `SET app.current_couple_id` her bağlantıda gerekir.
- **Schema-per-couple**: 10-15 çift için saçma; binlere ölçeklenince operasyonel kâbus.
