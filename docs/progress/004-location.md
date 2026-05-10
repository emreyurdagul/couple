# 004 — Konum takibi

**Tarih:** 2026-05-10 → …
**Durum:** 🟡 Phase 4a (backend) tamamlandı (`abf76e5`); mobil paket bekliyor

## Hedef

Çiftlerin **her an** birbirinin konumunu görebildiği, hareket halindeyken sık / hareketsizken seyrek güncellenen, geçmişin haritada iz olarak çizildiği ve "bugün ne kadar beraberdiniz" gibi türev metrikler üretebilen bir konum takibi katmanı kurmak.

İki büyük parça:
- **Phase 4a — Backend** (bu commit'te): hub + REST + bucketized beraber-süre metriği + retention.
- **Phase 4b — Mobil** (bekliyor): paketler, izin akışı, `LocationTracker` (OSS combo), data/state/UI, harita ekranı, home kartı.

## Adımlar

### Phase 4a — Backend (✅)

- [x] `CoupleSettings` entity (default 50m / 90gün / sharing on)
- [x] `DailyTogetherSummary` entity (gün-bazlı rollup)
- [x] `ILocationService` + DTO'lar (LocationInput, LocationDto, TogetherSummary, TogetherDay)
- [x] `LocationService` — record / record-batch / partner-current / list / together-summary
- [x] `TogetherCalculator` raw SQL — 1-dk bucket, AVG centroid, `ST_Distance(geography)` eşik
- [x] `CoupleDbContext` + DI: 2 yeni DbSet, scope filter, `AddScoped<ILocationService>`, 2 hosted service
- [x] `LocationHub` — `couple-loc:{id}` grubu, `SendLocation` server persist + `OthersInGroup.ReceiveLocation`
- [x] `LocationEndpoints` — POST /locations, /batch, GET /current, /, /together
- [x] `CoupleEndpoints.AcceptInvite` — invite kabulünde default `CoupleSettings` yaratımı
- [x] `TogetherSummaryRollupService` — UTC 03:17'de dünün özetini upsert
- [x] `LocationRetentionService` — 24h periyot, couple-couple retention günü üstü bulk delete
- [x] Migration `AddLocationServiceAndCoupleSettings`
- [x] `dotnet build` temiz (4 NU1903 uyarısı transitive — bu PR ile ilgisiz)
- [x] Smoke script `docs/progress/scripts/location-rest-smoke.sh`
- [ ] Smoke'u canlı API'ye karşı koşmak — dev DB up değil, kullanıcı çalıştırınca doğrulanacak

### Phase 4b — Mobil (⏸ bekliyor)

- [ ] Paketler: `flutter_map`, `latlong2`, `geolocator`, `flutter_foreground_task`, `workmanager`, `permission_handler`, `battery_plus`
- [ ] AndroidManifest + Info.plist — foreground service tag'leri (izinler zaten mevcut)
- [ ] `lib/core/config/app_config.dart` — `tileUrlTemplate` (geliştirme: OSM doğrudan), `tileAttribution`, `userAgentPackageName`
- [ ] `features/location/data/` — `location_models`, `location_repository`, `location_signalr_client`, `location_tracker` (OSS combo)
- [ ] `features/location/state/location_controller.dart` — Riverpod, my/partner/history/togetherToday, history pencere (1s/24s/7g)
- [ ] `features/location/presentation/map_screen.dart` — flutter_map + OSM tile, MarkerLayer, 50m altında `TogetherMarker`, PolylineLayer, segmented control
- [ ] `features/location/presentation/widgets/` — `together_marker`, `history_window_picker`
- [ ] `app_router.dart` — `/map` route + `hasCouple` guard
- [ ] `home_screen.dart` — Harita kartı + "bugün X dk beraber" mini metrik
- [ ] `main.dart` — Auth listener: login + couple → `LocationTracker.start()`, logout → `stop()`; permission_handler izin akışı
- [ ] Cihazda manuel test — kullanıcı UX onayı

## Kararlar

Mimari kararların gerekçeleriyle tamamı: [ADR-0008](../adr/0008-location-tracking.md). Kısa özet:

- **Mobil arka plan paketi**: OSS combo (`geolocator + flutter_foreground_task + workmanager`). flutter_background_geolocation iOS production lisansı $399 ödenmedi. `LocationTracker` interface'i ile ileride premium pakete geçiş tek concrete sınıf değişimi.
- **Tile sağlayıcısı**: Geliştirmede `tile.openstreetmap.org` doğrudan, key yok. Production öncesi mutlaka gerçek bir sağlayıcıya geçilecek (OSM Tile Usage Policy public app'te yasaklıyor). `app_config.dart`'ta tek noktadan değişir.
- **Beraber-süre algoritması**: 1-dk bucket'lar, kova centroid'i, `ST_Distance(geography)` eşik altı kova sayımı. Outlier `Accuracy > 50m`. Geçmiş günler hosted service'le rollup, bugün lazy compute.
- **Retention**: Ham `LocationPoint` 90 gün (couple ayar), `DailyTogetherSummary` sonsuz.
- **Merge eşiği**: `CoupleSettings.TogetherDistanceMeters` default **50 m** — sunucu metriği ve harita render'ı aynı parametreyi kullanır.
- **Realtime**: SignalR hub + REST hibrit, outbox kullanılmıyor.
- **Update sıklığı**: `geolocator` `distanceFilter: 10m, accuracy: high` → adaptif (hareketsizken sus, hareketteyken konuş).
- **Konum paylaşımı her zaman açık**: `CoupleSettings.LocationSharingEnabled` default `true`. Toggle UI v2'ye bırakıldı; backend'de altyapı hazır.

## Eklenen / Değişen dosyalar (Phase 4a — backend)

### Yeni
- `src/Couple.Domain/Entities/CoupleSettings.cs`
- `src/Couple.Domain/Entities/DailyTogetherSummary.cs`
- `src/Couple.Domain/Abstractions/ILocationService.cs` (LocationInput/Dto/TogetherSummary/TogetherDay + LocationSharingDisabledException)
- `src/Couple.Infrastructure/Location/LocationService.cs`
- `src/Couple.Infrastructure/Location/TogetherCalculator.cs`
- `src/Couple.Infrastructure/Location/TogetherSummaryRollupService.cs`
- `src/Couple.Infrastructure/Location/LocationRetentionService.cs`
- `src/Couple.Api/Endpoints/LocationEndpoints.cs` (LocationDtoMapper.From dahil)
- `src/Couple.Infrastructure/Persistence/Migrations/20260510191221_AddLocationServiceAndCoupleSettings.cs` (+ Designer)
- `docs/progress/scripts/location-rest-smoke.sh`

### Değişen
- `src/Couple.Api/Hubs/LocationHub.cs` — iskeletten `Hub<ILocationClient>`'e
- `src/Couple.Api/Endpoints/CoupleEndpoints.cs` — AcceptInvite default settings yaratımı
- `src/Couple.Api/Program.cs` — `MapLocationEndpoints()`
- `src/Couple.Infrastructure/Persistence/CoupleDbContext.cs` — 2 DbSet + 2 OnModelCreating bloğu
- `src/Couple.Infrastructure/DependencyInjection.cs` — `TogetherCalculator`, `ILocationService`, 2 hosted service
- `src/Couple.Infrastructure/Persistence/Migrations/CoupleDbContextModelSnapshot.cs`

## Doğrulama

```bash
# Build
cd backend && dotnet build       # 0 hata, 4 NU1903 (transitive — ayrı issue)

# Migration (dev DB up gerek)
dotnet ef database update -p src/Couple.Infrastructure -s src/Couple.Api

# Smoke (API ayakta + DB hazır)
BASE=http://localhost:5049 docs/progress/scripts/location-rest-smoke.sh
```

- ✅ Backend build temiz
- ⏸ Smoke çalıştırması bekliyor (dev DB up değil)
- ⏸ Cihazda manuel UX testi (Phase 4b sonrası)

### Kullanıcı doğrulaması gerekli (Phase 4a için)

Dev DB ayağa kalkınca:
1. Migration uygula: `dotnet ef database update -p backend/src/Couple.Infrastructure -s backend/src/Couple.Api`
2. API'yi başlat: `cd backend && dotnet run --project src/Couple.Api`
3. `docs/progress/scripts/location-rest-smoke.sh` koş — exit code 0, "Location REST smoke geçti" mesajı bekleniyor.

## Açık sorular / sonraki adıma taşınanlar

- [ ] Phase 4b mobil tüm paket — UX testi sonrası progress dosyası bu satırların altına genişler
- [ ] Konum paylaşımı toggle UI (CoupleSettings backend hazır, switch ekranı v2)
- [ ] Düşük pil otomatik downgrade
- [ ] Geofence ("eve geldi" bildirimleri)
- [ ] Trip / "beraber gidilen yerler" listesi
- [ ] Yer paylaşımı ("şu an buradayım" tek atımlık)
- [ ] iOS background tazeliği zayıfsa → flutter_background_geolocation premium kararı
- [ ] Production tile sağlayıcısı seçimi (Stadia / MapTiler / Mapbox / self-host)
- [ ] ADR-0007 chat (edit window 15 dk, delete scopes, reaction idempotency) — paralel ayrı iş
