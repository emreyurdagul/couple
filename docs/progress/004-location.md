# 004 — Konum takibi

**Tarih:** 2026-05-10 → 2026-05-11
**Durum:** 🟡 Phase 4a backend ✅ (`abf76e5`); Phase 4b mobile kod ✅, cihaz UX testi ⏸

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

- [x] Paketler: `flutter_map`, `latlong2`, `geolocator`, `flutter_foreground_task`, `workmanager`, `permission_handler`, `battery_plus`
- [x] AndroidManifest — foreground service + receiver kayıtları (`flutter_foreground_task`); Info.plist izinleri zaten mevcuttu
- [x] `lib/core/config/app_config.dart` — `tileUrlTemplate` (OSM dev), `tileAttribution`, `userAgentPackageName`, `togetherMergeMeters`
- [x] `features/location/data/` — `location_models`, `location_repository`, `location_signalr_client`, `location_tracker` (OSS combo + workmanager dispatcher)
- [x] `features/location/state/location_controller.dart` — Riverpod, my/partner/history/togetherToday, 1s/24s/7g pencere
- [x] `features/location/presentation/map_screen.dart` — flutter_map + OSM tile + MarkerLayer + 50m altında `TogetherMarker` + PolylineLayer + segmented control + "bugün X dk beraber" alt kart
- [x] `features/location/presentation/widgets/` — `together_marker`, `history_window_picker`
- [x] `app_router.dart` — `/map` route (couple guard mevcut redirect tablosundan geliyor: hasCouple false → /couple)
- [x] `home_screen.dart` — "Konum" kartı `/map`'e tıklanabilir + subtitle "Bugün X dk beraberdiniz"
- [x] `main.dart` — Auth listener: signedIn + coupleId → izin akışı (whileInUse → always + notification) + `tracker.start()`; logout → `stop()`
- [x] `flutter analyze` temiz (0 issues)
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

## Eklenen / Değişen dosyalar (Phase 4b — mobil)

### Yeni
- `mobile/couple_app/lib/features/location/data/location_models.dart` — LocationDto, LocationInput, TogetherDay, TogetherSummary
- `mobile/couple_app/lib/features/location/data/location_repository.dart` — REST (record / batch / partner-current / history / together)
- `mobile/couple_app/lib/features/location/data/location_signalr_client.dart` — `/hubs/location` ince sarmalayıcı (ChatSignalrClient deseninde, tek event ReceiveLocation)
- `mobile/couple_app/lib/features/location/data/location_tracker.dart` — `LocationTracker` interface + `OssLocationTracker` (geolocator stream + flutter_foreground_task notification + workmanager 15dk fallback)
- `mobile/couple_app/lib/features/location/state/location_controller.dart` — Riverpod NotifierProvider; my/partner last + history + togetherToday + connection + history window
- `mobile/couple_app/lib/features/location/presentation/map_screen.dart` — flutter_map + OSM tile + polyline + marker (50m altında TogetherMarker) + segmented control + "bugün" kartı
- `mobile/couple_app/lib/features/location/presentation/widgets/together_marker.dart`
- `mobile/couple_app/lib/features/location/presentation/widgets/history_window_picker.dart`

### Değişen
- `mobile/couple_app/pubspec.yaml` — yedi yeni paket; `workmanager: ^0.9.0+3` (Flutter 3.29 v2 embedding uyumu için 0.5.2 yerine)
- `mobile/couple_app/android/app/src/main/AndroidManifest.xml` — `flutter_foreground_task` Service + Receiver kayıtları
- `mobile/couple_app/lib/core/config/app_config.dart` — tile + userAgent + togetherMergeMeters
- `mobile/couple_app/lib/core/config/app_router.dart` — `/map` route
- `mobile/couple_app/lib/features/home/presentation/home_screen.dart` — "Konum" kartı `/map` tıklanabilir + togetherToday subtitle
- `mobile/couple_app/lib/main.dart` — Auth listener: signedIn+coupleId → izin akışı + `tracker.start()`; logout → `stop()`

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
- ✅ Mobil `flutter analyze` temiz (0 issue)
- ⏸ Cihazda manuel UX testi (kullanıcı doğrulaması bekleniyor)

### Kullanıcı doğrulaması gerekli (Phase 4a için)

Dev DB ayağa kalkınca:
1. Migration uygula: `dotnet ef database update -p backend/src/Couple.Infrastructure -s backend/src/Couple.Api`
2. API'yi başlat: `cd backend && dotnet run --project src/Couple.Api`
3. `docs/progress/scripts/location-rest-smoke.sh` koş — exit code 0, "Location REST smoke geçti" mesajı bekleniyor.

### Kullanıcı doğrulaması gerekli (Phase 4b için)

İki gerçek cihazda (veya emülatör + cihaz):
1. Login → izin akışı: whileInUse dialog → Always promote → bildirim izni → Harita kartı "Bugün — beraber"
2. `/map` → kalıcı bildirim "Konum paylaşımı açık" görünür
3. İki cihazı 50m altı → tek "biz" imleci; PolylineLayer kendi/partner ayrı renkte
4. Cihazları 200m+ uzaklaştır → ayrı imleçler, ayrı polyline'lar
5. Segmented control 1s/24s/7g → polyline penceresi güncellenir
6. Uygulamayı kapat (terminate) → ~15dk içinde workmanager periyodik POST yapıyor mu (backend log)
7. Home kartında "Bugün X dk beraberdiniz" güncel
8. Logout → bildirim kaybolur, tracker durur

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
