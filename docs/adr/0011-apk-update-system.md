# ADR-0011: Dinamik APK güncelleme sistemi (in-app update)

**Status:** Accepted
**Tarih:** 2026-05-12

## Context

Mobile-only dağıtım (Play Store dışı, kurum içi APK install) için bir güncelleme akışı gerekli:

- Kullanıcı yeni sürümü manuel arayıp indirmek zorunda kalmasın.
- Backend API'yi değiştirdiğimizde minimum desteklenen mobile sürümü zorunlu güncelleme ile bloklayabilelim (auth + couple-scoping ihlallerini önle).
- APK barındırma için yeni bir CDN/registry servisi ekleme istemiyoruz (Phase 5a stack'i Postgres + MinIO + API; MinIO public access yapmak için ek Traefik labelları ve presigned URL akışı gerek, şimdilik gereksiz karmaşıklık).

## Decision

**API kendisi APK'ları sunar; mobile her başlatmada `GET /api/version/latest`'i çağırır.**

### Backend

- Yeni entity `AppVersion(Id, Platform, VersionCode, VersionName, FileName, SizeBytes, Sha256, MinSupportedVersionCode, ReleaseNotes, CreatedAt)`.
- `GET /api/version/latest?platform=android&currentVersionCode=N` (anonim) → en yüksek `VersionCode`'lu kaydı döner; `updateAvailable = latest > current`, `mandatory = current < minSupportedVersionCode`.
- `POST /api/admin/versions` (multipart, `X-Admin-Token` header) → APK yükle, dosya `/app/uploads/apks/<platform-versionCode-guid>.apk`'a yazılır, sha256 hesaplanır, aynı `(platform, versionCode)` varsa overwrite (eski dosya silinir).
- `GET /downloads/{filename}` → static file middleware, `application/vnd.android.package-archive` MIME tipi.
- Kestrel + FormOptions upload limit 250 MB (default 28 MB upload akışını kırıyordu — 413).
- Docker volume: `api_uploads:/app/uploads` (deploy'lar arası persist).

### Mobile

- `VersionService.checkForUpdate()` → `package_info_plus` ile mevcut `buildNumber`'ı okur, endpoint'i çağırır, `updateAvailable=true` ise `VersionInfo` döner.
- `VersionService.downloadApk()` → Dio ile cache dizinine indirir; aynı sha+size varsa skip (retry ucuz).
- `VersionService.installApk()` → `open_filex` ile sistem package installer'ını tetikler. Kullanıcı "Bilinmeyen kaynaklardan yükle" iznini bir kere onaylar.
- `UpdateDialog` → opsiyonel ("Sonra"/"Güncelle") veya zorunlu (dismiss edilemez) varyantlar, ilerleme çubuğu, hata recovery.
- Trigger noktası: `authController` listener'ında auth state `AuthInitializing`'den çıkınca **400 ms gecikmeyle** check tetiklenir. Gecikme GoRouter redirect'inin tamamlanmasını bekler — yoksa dialog router redirect tarafından pop'lanır.
- `REQUEST_INSTALL_PACKAGES` izni AndroidManifest'e eklendi.

### Auth

- Admin token tek değer (`ADMIN_TOKEN` env). Phase 5b kapsamında role-based admin user yok; rotation gerekirse Coolify env update + redeploy.

## Consequences

- ➕ Single point of distribution: API her şeyi sunar, ayrı registry yok.
- ➕ sha256 ile bütünlük kanıtı (mobile dedup + isteyen kullanıcı manuel verify edebilir).
- ➕ `MinSupportedVersionCode` ile uyumsuz client'ları zorla güncelleme akışına sokabiliyoruz (backend API breaking change için kaldıraç).
- ➖ APK boyutu (~30-43 MB) Coolify API container'ından geçer → her güncelleme uploads volume'ü büyütür. Eski sürümleri purge eden bir housekeeping job (Phase 5c?) düşünülmeli.
- ➖ Single admin token; ileride çoklu admin/audit için Identity role'leri (`Admin`) gerekecek.
- 🔁 MinIO public erişim ileride kurulursa: APK download URL'lerini MinIO'ya yönlendirip API'yi statik dosyadan kurtarabiliriz; sha256 metadata uyumlu kalır.

### split-per-abi versionCode tuhaflığı

Flutter `flutter build apk --split-per-abi` ABI başına versionCode'a offset ekler: `base + abi_offset * 1000` (arm64=2, armv7=1, x86_64=4). Phase 5b cihaz testinde universal APK ile devam edildi (`--target-platform=android-arm64` → offset YOK, versionCode pubspec'teki +N'ye eşit). Üretim akışında ya:

- Tek universal APK build (`flutter build apk --release`), tüm cihazlara aynı dosya — basit, ~42 MB.
- Ya da split build ve backend yanıtında ABI'ye göre URL seçimi (request'ten `User-Agent` veya yeni bir `abi` query parametresi).

Şimdilik universal seçildi; trade-off çıktıda dökümante edilecek.

## Alternatives considered

- **Play Store internal testing track** — Google hesabı, paketleme şartları, review zamanı; mobile-first kurum içi MVP için aşırı.
- **GitHub Releases** — private repo asset download token gerektirir; cihaza token gömmek kötü güvenlik pratiği.
- **MinIO public bucket + presigned URL** — Coolify Traefik için ekstra label/domain konfigürasyonu; presigned URL üretmek için Storage adapter implementasyonu (henüz `Couple.Infrastructure/Storage` boş). APK use-case için aşırı; chat medya için tekrar gündeme gelecek.
- **install_plugin paketi** — bakım az, OpenFilex daha aktif ve modern Android intent handling.
