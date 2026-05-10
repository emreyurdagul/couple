# 001 — Çekirdek iskelet (backend + mobile + infra)

**Tarih:** 2026-05-10
**Durum:** ✅ Tamamlandı
**Commit:** `da94502` chore: bootstrap couple monorepo

## Hedef

Sıfırdan monorepo iskeletini kurmak: .NET 10 backend (3 proje), Flutter mobil projesi ve docker-compose tabanlı altyapı dosyaları. Çalışan derleme + test + temel mimari sütunlar (couple-scoping, outbox, JWT) yerinde.

## Kararlar

- **.NET 10** + EF Core 10 + Npgsql + NetTopologySuite → bkz. ADR-0001
- **PostgreSQL + PostGIS** tek veritabanı; Redis MVP'de yok → bkz. ADR-0001
- **SignalR** chat + konum için tek realtime pipeline → bkz. ADR-0001
- **Couple-scoped multi-tenancy** EF global query filter + SaveChanges interceptor → bkz. ADR-0002
- **Offline-first + Outbox pattern** → bkz. ADR-0003
- **JWT'de `couple_id` claim**; SignalR query-string token akışı (`/hubs/*`)
- **Identity** için `AddIdentityCore<ApplicationUser>` + `AddRoles` + `AddEntityFrameworkStores` (UI ve SignInManager kullanılmıyor; JWT için yeterli)
- **Flutter** stack: Riverpod 2 + go_router + Dio + Drift + signalr_netcore + flutter_map + flutter_background_geolocation + qr_flutter + mobile_scanner + image_picker + record + just_audio + firebase_messaging
- **Solution dosyası** `.slnx` formatında (.NET 10 default)

## Eklenen / Değişen dosyalar

### backend/
- `Couple.slnx` — solution (3 proje)
- `Dockerfile`, `.dockerignore`
- `src/Couple.Api/Program.cs` — JWT, SignalR, EF, health, Serilog DI
- `src/Couple.Api/Auth/CurrentUser.cs` — `ICurrentUser` impl (claims → user/couple_id)
- `src/Couple.Api/Auth/JwtTokenService.cs` — access token üretici
- `src/Couple.Api/Hubs/ChatHub.cs`, `LocationHub.cs` — `[Authorize]` boş iskelet
- `src/Couple.Api/appsettings.json` — connection string + Jwt + Storage konfig
- `src/Couple.Domain/Abstractions/ICoupleScoped.cs`, `ICurrentUser.cs`
- `src/Couple.Domain/Entities/{Couple,CoupleInvite,Message,LocationPoint,DeviceToken,OutboxEvent}.cs`
- `src/Couple.Infrastructure/DependencyInjection.cs` — `AddCoupleInfrastructure`
- `src/Couple.Infrastructure/Identity/ApplicationUser.cs` — `IdentityUser<Guid>`
- `src/Couple.Infrastructure/Persistence/CoupleDbContext.cs` — Identity + entityler + global query filter + PostGIS
- `src/Couple.Infrastructure/Persistence/Interceptors/CoupleScopingInterceptor.cs` — yazma sırasında couple_id auto-set + scope kontrolü
- `src/Couple.Infrastructure/Persistence/DesignTimeDbContextFactory.cs` — migration için
- `src/Couple.Infrastructure/Outbox/{IOutboxPublisher,OutboxPublisher,OutboxDispatcher}.cs`

### mobile/couple_app/
- `pubspec.yaml` — tüm planlanan paketler
- `lib/main.dart` — `ProviderScope` + `MaterialApp.router`
- `lib/core/config/app_router.dart` — go_router iskeleti (placeholder ekran)
- `lib/core/config/app_config.dart` — `apiBaseUrl` (--dart-define ile override)
- `lib/core/theme/app_theme.dart` — light + dark seed `#E63946`
- `test/widget_test.dart` — boot smoke testi
- Klasör iskeleti: `core/{network,sync,storage}`, `features/{auth,couple,chat,location}/{data,presentation}`, `shared/widgets`

### infra/
- `docker-compose.yml` — postgres-postgis 16 + minio + caddy + api
- `Caddyfile` — reverse proxy (hub keepalive 1h)
- `.env.example` — secret template

### kök
- `.gitignore`, `README.md`

## Doğrulama

```bash
cd backend && dotnet build       # 0 hata, 4 NU1903 uyarı (transitive Crypto.Xml — Identity 9 zinciri)
cd mobile/couple_app && flutter analyze   # 1 cosmetic info
cd mobile/couple_app && flutter test      # 1/1 geçti
git log --oneline -1             # da94502
```

## Açık sorular / sonraki faza taşınanlar

- [ ] **Dev DB stratejisi**: Docker yüklü değil; ya Docker kurulacak ya da lokal Postgres 18'e PostGIS extension manuel eklenecek
- [ ] **JWT secret**: prod için güvenli üretim akışı (`openssl rand -base64 48`) deploy talimatına yazılmalı
- [ ] **EF Core migration** henüz oluşturulmadı (Phase 2 başında)
- [ ] **NU1903** uyarısı: Identity 9 transitive `System.Security.Cryptography.Xml` 9.0.0 — vuln var; Identity 10.0.x serisine geçiş veya explicit override gerekebilir
- [ ] **Apple Developer hesabı + domain** operasyonel ön gereksinimler (yayın öncesi)
