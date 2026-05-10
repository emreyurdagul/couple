# 002 — Auth + Couple davet

**Tarih:** 2026-05-10 → …
**Durum:** 🟡 Devam ediyor

## Hedef

E-posta/parola ile kayıt + login (JWT access + refresh), 6 haneli kod ve QR ile çift daveti, kabul akışı, soft-archive `DELETE /couples/me`. Mobil tarafta onboarding + auth + davet ekranları.

## Adımlar

- [x] **Lokal dev DB hazırlığı** — Podman ile postgres-postgis 16 container başlatıldı, `couple_dev` DB + PostGIS 3.4 extension; 15 tablo + EFMigrationsHistory aktif
- [x] **İlk EF Core migration** (`InitialSchema`) — Identity + couple-scoped entity'ler + outbox + indeksler + GIST index `LocationPoints.Position` üstünde
- [ ] Auth endpoint'leri (`/auth/register`, `/auth/login`, `/auth/refresh`, `/auth/logout`) + `RefreshToken` entity
- [ ] `/couples/invites` (POST) + `/couples/invites/{code}/accept` (POST) + `GET /couples/me` + `DELETE /couples/me`
- [ ] JWT yenileme: eşleşme/ayrılma sonrası `couple_id` claim güncellemesi
- [ ] Couple-scope query filter'a `Couple.Status == Active` koşulu (ADR-0004)
- [ ] Mobil: kayıt/giriş ekranları, davet üret (QR + 6 haneli kod), partner kodu gir/QR tara, eşleşme onay ekranı

## Kararlar

- **Refresh token:** server-side rotating, DB'de hash'li tutulur (`AspNetUserTokens` Identity tablosu yeterli olabilir; ek `RefreshTokens` tablosu gerekirse açacağım)
- **Davet kodu:** 6 haneli BASE32 (kafiyeli + okunaklı), 24 saat TTL, çakışmazsa unique
- **Soft-archive query filter:** EF global query filter'da `Couple.Status` joined kontrol; navigation property eklemek gerek; karmaşa olursa `EF.Property` ile manuel kontrol
- **Migration komutu (Fedora dev):** factory kaldırıldığı için EF Tools `Program.cs`'in IHostBuilder'ı üstünden çalışır → `dotnet ef database update --project src/Couple.Infrastructure --startup-project src/Couple.Api` (env: ASPNETCORE_ENVIRONMENT=Development default'la appsettings.Development.json okunur)

## Eklenen / Değişen dosyalar (devam ediyor)

- `backend/src/Couple.Infrastructure/Persistence/Migrations/20260510153703_InitialSchema.{cs,Designer.cs}` — ilk şema
- `backend/src/Couple.Infrastructure/Persistence/Migrations/CoupleDbContextModelSnapshot.cs`
- `backend/src/Couple.Infrastructure/Persistence/DesignTimeDbContextFactory.cs` — **silindi** (EF Tools Program.cs üstünden gidiyor; appsettings env-aware)
- `infra/docker-compose.yml` — fully-qualified imaj adları (`docker.io/...`); volume'ler bind-mount yerine **named volume** (rootless Podman UID uyumsuzluğunu çözmek için)

## Doğrulama (şimdiye kadar yapılan)

```bash
# Postgres + PostGIS
podman exec couple-postgres pg_isready -U postgres        # accepting connections
podman exec couple-postgres psql -U postgres -d couple_dev -c "SELECT PostGIS_Version();"
# 3.4 USE_GEOS=1 USE_PROJ=1 USE_STATS=1

# EF migration
dotnet ef database update --project src/Couple.Infrastructure --startup-project src/Couple.Api
# Applying migration '20260510153703_InitialSchema' → Done.

podman exec couple-postgres psql -U postgres -d couple_dev -c "\dt"
# 15 tablo (Identity + couple-scoped + outbox + EFMigrationsHistory + spatial_ref_sys)
```

### Kullanıcı doğrulaması gerekli

Bu noktada API endpoint'i henüz yok, doğrulama setup düzeyinde. Test edilecek bir UX yok.

## Açık sorular / sonraki faza taşınanlar

- [ ] NU1903 uyarısı (System.Security.Cryptography.Xml 9.0.0 → vuln) — Identity 10.0 paketinin transitive zinciri; explicit override eklemek mi (`<PackageReference Include="System.Security.Cryptography.Xml" Version="..." />`) yoksa Identity 10 minor güncellemesini beklemek mi?
- [ ] Refresh token rotasyon ve revocation stratejisi (basit: DB'de hash + revoked flag) — `IdentityUserToken` mı, ayrı tablo mı?
