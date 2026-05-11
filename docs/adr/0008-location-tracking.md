# ADR-0008: Konum takibi — paket seçimi, beraber-süre algoritması, retention

**Status:** Accepted
**Tarih:** 2026-05-10

## Context

Phase 4'te canlı konum paylaşımı kuruluyor. Kullanıcı tek koşul olarak "her an konumun paylaşılıyor olması mühim" dedi; ileride "beraber geçirilen süre" gibi türev metrikler ve harita üzerinde imleçlerin yakınsa birleşmesi de plan dahilinde.

Kararlar üç eksende:
1. **Mobil arka plan konum paketi** — pil dostu, terminate sonrası ayağa kalkabilen, Doze altında çalışan bir çözüm gerek.
2. **"Beraber geçirilen süre" algoritması** — performant + retention sonrası bozulmayan + günlük rollup'a uygun.
3. **Saklama (retention)** — ham nokta + özet ayrımı, disk maliyeti dengesi.

ADR-0005 başlangıçta `flutter_background_geolocation` (transistorsoft) ve Stadia tile öneriyordu. Phase 4'e gelirken iki kısıt netleşti:
- iOS üretim lisansı $399 → kullanıcı ödememeyi seçti.
- Stadia hesabı açma sürtünmesi şimdilik atlanıyor; geliştirme OSM doğrudan ile yapılıyor.

## Decision

### 1) Mobil arka plan konum paketi: OSS combo

`geolocator + flutter_foreground_task + workmanager + permission_handler`

- **Foreground**: `geolocator.getPositionStream(LocationSettings(accuracy: high, distanceFilter: 10m))` — hareketsizken yayın susar, hareketteyken konuşur. Stream callback → SignalR push (varsa) + REST POST.
- **Android arka plan**: `flutter_foreground_task` kalıcı bildirim + foreground service ile Doze'a girmez; `workmanager` ile 15 dakikalık (OS minimum) periyodik check + `geolocator.getCurrentPosition` → REST POST batch.
- **iOS arka plan**: `UIBackgroundModes: location` + `geolocator` significant location changes (~500m hassasiyet). "Her an" tazeliği iOS'ta zayıf; iOS launch öncesi premium pakete geçiş kararı tekrar değerlendirilir.
- **Tracker arayüzü**: kod tarafında `LocationTracker` interface'i + `OssLocationTracker` concrete; ileride premium pakete geçiş tek dosya.

### 2) Beraber-süre algoritması: 1-dakikalık bucketize

Her kullanıcı için `date_trunc('minute', RecordedAt)` kovaları, kova içi `AVG(ST_X)+AVG(ST_Y)` ile centroid; iki kullanıcının aynı kovadaki centroid'leri arasındaki `ST_Distance(geography)` couple-spesifik eşik (varsayılan 50 m) altındaysa o dakika "beraber" sayılır.

- **Outlier filtresi**: `Accuracy > 50 m` noktalar elenir.
- **Sliding window'a göre seçim nedeni**: O(N+M) tek SQL sorgusu, retention sonrası bozulmaz, günlük rollup'a doğal uyum.
- **Hesaplama yeri**:
  - **Geçmiş günler** → her gece UTC 03:17'de `TogetherSummaryRollupService` aktif couple'lar için dünün özetini compute eder, `DailyTogetherSummary` upsert. Tablodan okunur.
  - **Bugünü kapsayan sorgu** → `LocationService.GetTogetherSummaryAsync` çağrısı sırasında lazy compute. Tablo yok, tek SQL.

### 3) Retention: ham 90 gün + özet sonsuz

- `LocationPoint` her couple için `CoupleSettings.LocationHistoryRetentionDays` (default 90) günden eski olanları `LocationRetentionService` günlük bulk delete (`ExecuteDeleteAsync`).
- `DailyTogetherSummary` sonsuz tutulur; ileride aylık/yıllık rollup'lar buradan beslenir.
- 1 nokta/dakika × 2 kullanıcı × 90 gün ≈ 260k satır/çift; PostGIS rahat.

### 4) Birleşme eşiği: parametrik

`CoupleSettings.TogetherDistanceMeters` (default **50 m**). UI tarafında kendi ve partner imleçleri haversine ile bu mesafenin altındaysa tek "biz" imlecine dönüşür. Sunucu metriği aynı parametreyi kullanır → görsel ile rakam tutarlı.

### 5) Realtime kanalı: SignalR + REST hibrit

- `LocationHub` `couple-loc:{id}` grubu; foreground `SendLocation` invoke → diğer cihaza `ReceiveLocation` push.
- Arka plan REST `POST /locations` (single) ve `POST /locations/batch` (workmanager flush) → endpoint kayıt sonrası `IHubContext` ile partner cihazına push (partner foreground'daysa eli boş kalmaz).
- Outbox **kullanılmıyor**: high-frequency event; latency + tablo şişmesi yarardan fazla zarar verir. SignalR bağlantısı koparsa partner `GET /locations/current` ile kapatır.

## Consequences

- ➕ Lisans masrafı yok, tüm bağımlılıklar MIT/BSD.
- ➕ Geçmiş günler + lazy bugün hibridi sayesinde "bugün X dk beraber" sorgusu 1 SQL'de döner; geçmiş aylar ucuz tablo okuması.
- ➕ Retention parametrik; couple bazında değişebilir.
- ➕ Tracker interface'i sayesinde ileride premium pakete (ya da tamamen native modül) geçiş tek concrete sınıf değişimi.
- ➖ iOS arka plan tazeliği `geolocator` ile sınırlı (~500m significant changes). "Her an" hissi iOS'ta zayıf — kullanıcı şikayetçiyse premium karar tekrar.
- ➖ Workmanager Android'de 15 dk minimum periyot; uygulama tamamen kill edilmiş + kullanıcı uzun süre hareketsizse tazelik 15 dk gecikebilir.
- ➖ `flutter_foreground_task` kalıcı bildirim çubuğunu meşgul eder; bazı kullanıcılar rahatsız bulabilir.
- ➖ Bucket boyutu 1 dakika sabit; kısa süreli (örn. 30 sn) yan yana geçişler yakalanmaz. MVP için kabul edilebilir takas.
- 🔁 Premium pakete dönüş: `LocationTracker` arayüzünün başka concrete'ini yaz, `main.dart`'taki binding'i değiştir.
- 🔁 Bucket çözünürlüğünü değiştirme: `TogetherCalculator` raw SQL'inde `date_trunc('minute', ...)` tek noktada parametrize edilir.
- 🔁 Retention politikasını değiştirme: `CoupleSettings.LocationHistoryRetentionDays` per-couple update.

## Alternatives considered

- **flutter_background_geolocation (transistorsoft)** — Olgun motion detection, adaptif distance filter, native öne doğru çıkmış. Android OSS, iOS production $399 → ödenmedi.
- **Sliding window beraber-süre** — Her noktayı her noktayla karşılaştır: O(N×M). 90 günlük geçmişte mantıksız maliyet. Bucketize ile aynı sonuç, çok daha ucuz.
- **Outbox üzerinden konum publish** — Diğer event'lerle simetri kurabilirdi ama high-frequency yüzünden tabloyu şişirirdi. Realtime kanalı doğrudan SignalR hub yeterli, kayıp durumu için partner `GET /current` fallback'i mevcut.
- **DailyTogetherSummary lazy-only (hosted service yok)** — Her sorguda son 90 günü compute etmek 90 ayrı SQL × 2 user. Hosted service ile sadece dünü hesaplamak amortize ediyor.
- **Sınırsız ham retention** — 1 yıl × 2 user × 1440 dk ≈ 1M satır/çift × N çift. PostGIS hâlâ çalışır ama günlük rollup zaten olduğu için ham veriyi 90 günde silmek pratik.

## Uygulama notları (2026-05-11, Phase 4b)

- **`workmanager` sürümü ^0.5.2 → ^0.9.0+3**: 0.5.2 hâlâ Flutter v1 embedding'in (`ShimPluginRegistry`, `PluginRegistrantCallback`) API'larını kullanıyordu; bunlar Flutter 3.29 ile kaldırıldı ve `:workmanager:compileDebugKotlin` fail oluyordu. 0.9.x federated platform'a (workmanager_android / workmanager_apple) geçmiş durumda; API ufak değişiklikler: `existingWorkPolicy` parametresi artık `ExistingPeriodicWorkPolicy` enum'unu istiyor, `isInDebugMode` deprecated (WorkmanagerDebug handlers tavsiyesi).
- **flutter_foreground_task `TaskHandler.onStart`** v8.x'te `Future<void>` döner (önceden `void`). `_LocationForegroundTaskHandler` buna göre yazıldı.
- **`Position.timestamp`** geolocator 13.x'te artık non-nullable; `?? DateTime.now()` fallback gerekmedi.
