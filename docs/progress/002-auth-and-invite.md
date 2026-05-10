# 002 — Auth + Couple davet

**Tarih:** 2026-05-10
**Durum:** 🟢 Backend yeşil + mobil iskelet hazır; **kullanıcı doğrulaması bekleniyor**

## Hedef

E-posta/parola ile kayıt + login (JWT access + refresh), 6 haneli kod ve QR ile çift daveti, kabul akışı, soft-archive `DELETE /couples/me`. Mobil tarafta onboarding + auth + davet ekranları.

## Adımlar

- [x] **Lokal dev DB hazırlığı** — Podman ile postgres-postgis 16 container başlatıldı, `couple_dev` DB + PostGIS 3.4 extension; 15 tablo + EFMigrationsHistory aktif
- [x] **İlk EF Core migration** (`InitialSchema`) — Identity + couple-scoped entity'ler + outbox + indeksler + GIST index `LocationPoints.Position` üstünde
- [x] **Auth endpoint'leri** (`/auth/register`, `/auth/login`, `/auth/refresh`, `/auth/logout`) + `RefreshToken` entity + rotating + revoke
- [x] **Couple endpoint'leri** (`/couples/invites`, `/couples/invites/{code}/accept`, `GET /couples/me`, `DELETE /couples/me`) — soft-archive
- [x] **JWT couple_id güncellemesi** refresh akışında (token yenilenince `GetActiveCoupleIdAsync` ile claim eklenir/çıkarılır)
- [x] **E2E curl smoke**: register × 2 + davet + kabul + refresh + me + delete + 404 — `docs/progress/scripts/auth-and-invite-smoke.sh`
- [ ] **Couple-scope query filter'a `Status==Active` koşulu** — şu an `IgnoreQueryFilters` ile manuel kontrol; chat/konum entity'leri eklenince navigation property + filter ile
- [x] **Mobil**: Login/Register/Onboarding/InviteCreate (QR+kod)/InviteAccept (manuel+QR scanner)/Home iskeleti
- [x] **Mobil widget testleri**: form validation + onboarding CTAs (3/3 yeşil)
- [x] **Android Manifest** + **iOS Info.plist**: kamera/mikrofon/fotoğraf/konum/arka plan/cleartext (dev) izinleri
- [x] **go_router redirect**: AuthInitializing → /splash, SignedOut → /login, SignedIn (no couple) → /couple, SignedIn (has couple) → /

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

## Doğrulama

```bash
# Postgres + PostGIS
podman exec couple-postgres pg_isready -U postgres        # accepting connections
podman exec couple-postgres psql -U postgres -d couple_dev -c "SELECT PostGIS_Version();"
# 3.4 USE_GEOS=1 USE_PROJ=1 USE_STATS=1

# EF migrations
dotnet ef database update --project src/Couple.Infrastructure --startup-project src/Couple.Api
# Applied: 20260510153703_InitialSchema, 20260510154406_AddRefreshTokens

# Build
cd backend && dotnet build         # 0 hata, 4 NU1903 uyarı (Identity 9 transitive)

# E2E smoke (otomatik — AI tarafından çalıştırıldı, geçti)
cd backend/src/Couple.Api && dotnet run --no-build &
docs/progress/scripts/auth-and-invite-smoke.sh
# Sonuç: tüm 8 adım yeşil, soft-archive sonrası /couples/me 404 döndü
```

### Kullanıcı doğrulaması gerekli (Phase 2 kapanışı için)

Mobil iskelet hazır. Çalıştırma talimatı: [`docs/progress/scripts/mobile-dev-run.md`](scripts/mobile-dev-run.md). 2 emülatör veya 1 emülatör + 1 fiziksel cihazla:

1. **Cihaz A** → kayıt ol → onboarding'e otomatik geçmeli
2. **Cihaz A** → "Davet kodu oluştur" → 6 haneli kod ve QR görünmeli
3. **Cihaz B** → kayıt ol (farklı e-posta)
4. **Cihaz B** → "Partner kodunu gir / QR tara"
   - **Manuel kod yolu:** kodu yaz → "Eşleş"
   - **QR yolu:** QR tab'a geç, kamera izni ver, A'nın QR'ına tut
5. Cihaz B Home ekranına geçmeli, partner adı "Alice" görünmeli
6. **Cihaz A** uygulamayı tamamen kapat, tekrar aç → otomatik Home (eski oturumdan stored token; ama coupleId stored değildi; redirect Home'a gitmesi için token refresh sonrası coupleId set olmalı — **bu noktayı manuel doğrulayın**: cihaz A onboarding'e mi yoksa Home'a mı düşüyor?)
7. **Cihaz B** üst sağ "kalp kırığı" ikonu → "Sonlandır" → Cihaz B Login ekranına dönmeli
8. **Cihaz A** bir API isteği yapmaya çalışsın (uygulamayı yeniden açarak) → 401 alıp refresh deneyecek, refresh revoke olduğu için login ekranına dönmeli

Bu listede problem yaşadığınız her adımı bana bildirin; düzeltip yeniden test ederiz.

#### Bilinen kısıtlar

- Geri butonu davranışı (system back) bazı yerlerde explicit go ile yönlendiriyor; native back stack ile uyumsuz olabilir.
- ~~6 numaralı senaryo: oturum geri yüklendiğinde stored couple_id eksikse onboarding'e atar.~~ **Çözüldü:** `AuthController._restore` artık restore sonrası `refresh()` çağırıyor; backend güncel `couple_id` claim'ini döndürüp stored değeri günceller.

## Açık sorular / sonraki faza taşınanlar

- [ ] NU1903 uyarısı (System.Security.Cryptography.Xml 9.0.0 → vuln) — Identity 10.0 paketinin transitive zinciri; explicit override eklemek mi (`<PackageReference Include="System.Security.Cryptography.Xml" Version="..." />`) yoksa Identity 10 minor güncellemesini beklemek mi?
- [ ] Refresh token rotasyon ve revocation stratejisi (basit: DB'de hash + revoked flag) — `IdentityUserToken` mı, ayrı tablo mı?
