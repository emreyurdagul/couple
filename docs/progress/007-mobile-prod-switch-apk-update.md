# 007 — Mobile prod switch + dinamik APK güncelleme (Phase 5b)

**Tarih:** 2026-05-11 → 2026-05-12
**Durum:** 🟢 Backend + mobile tamam; cihaz testi başarılı (Samsung A34, fix-li dialog auth-stable trigger ile düzgün açılıyor)

## Hedef

Phase 5a deploy sonrası mobile uygulamasını production API'ye yönlendir + Play Store dışında yayın için in-app APK update sistemi kur.

## Kararlar

- `AppConfig.apiBaseUrl` `kReleaseMode`-aware: release → Coolify FQDN, debug → `10.0.2.2:8080`, override `--dart-define=API_BASE_URL=...` her iki modda → adım 1
- Custom domain atlandı, sslip.io HTTP'de devam (kullanıcı tercihi) → step 2 skipped
- MinIO public atlandı, APK'ları API doğrudan static file middleware ile sunar → step 3 deferred
- APK update sistemi: `AppVersion` entity + `/api/version/latest` + `/api/admin/versions` (multipart, admin token) + `/downloads/{file}` static → ADR-0011
- Mobile: `VersionService` + `UpdateDialog` + `open_filex` installer; trigger auth listener'da `AuthInitializing` çıkınca + 400ms delay → GoRouter redirect dialog'u pop'lamasın
- Kestrel upload limit 250 MB (default 28 MB → APK 42 MB için 413 veriyordu)

## Eklenen / Değişen dosyalar

### Backend
- `Couple.Domain/Entities/AppVersion.cs` — entity (yeni)
- `Couple.Infrastructure/Persistence/CoupleDbContext.cs` — DbSet + index
- `Couple.Infrastructure/Persistence/Migrations/20260511211512_AddAppVersions.*` — migration
- `Couple.Api/Endpoints/VersionEndpoints.cs` — GET latest + POST admin upload (yeni)
- `Couple.Api/Program.cs` — Kestrel/FormOptions 250 MB, static file middleware `/downloads/`, `MapVersionEndpoints`

### Mobile
- `lib/core/config/app_config.dart` — `kReleaseMode` ternary default
- `lib/core/update/version_service.dart` — VersionInfo model + service (yeni)
- `lib/core/update/update_dialog.dart` — opsiyonel/zorunlu dialog + progress (yeni)
- `lib/main.dart` — auth listener içinde `_checkForUpdate`, 400 ms delay
- `pubspec.yaml` — `package_info_plus`, `open_filex` + sürüm bump
- `android/app/src/main/AndroidManifest.xml` — `REQUEST_INSTALL_PACKAGES`

### Infra
- `docker-compose.yaml` — `api_uploads` named volume, `Admin__Token` env, `Storage__UploadsPath=/app/uploads`
- Coolify env: `ADMIN_TOKEN` seed edildi (rotation: env_vars update)

### Docs
- `docs/adr/0011-apk-update-system.md` — yeni
- `docs/progress/INDEX.md` — 007 + ADR-0011 satırı

## Doğrulama

```bash
# Backend
curl http://vgvexxga7f7ah4puhujzkh60.72.61.95.76.sslip.io/api/version/latest?platform=android&currentVersionCode=3
# → updateAvailable:true, latestVersionCode:2003, downloadUrl, sha256, size

curl -I http://vgvexxga7f7ah4puhujzkh60.72.61.95.76.sslip.io/downloads/android-2003-...apk
# → HTTP 200, application/vnd.android.package-archive, 42 MB
```

### Cihaz testi (Samsung A34, arm64)

1. v1 baseline (versionCode=2001 — fix'siz dialog logic) → cihaza adb install → açılışta dialog görünür ama GoRouter redirect dialog'u pop'larken kullanıcı tıklayamadan kayboldu (BUG keşfi).
2. Fix: `main.dart`'ta version check `AuthInitializing`'den çıktıktan sonra 400 ms delay ile tetiklendi.
3. Fix'li v3 (versionCode=3, universal) cihaza ADB ile yüklendi; backend'e fix'li v4 versionCode=2003 olarak yüklendi.
4. Cihaz açıldı → dialog router redirect'ten sonra düzgün açıldı → "Güncelle" → indirme → install ✅ (kullanıcı doğruladı).

## Karşılaşılan sorunlar ve çözümler

1. **Env var duplicate'ları** (Phase 5a kalıntısı) — Coolify auto-populate ile manuel POST race, boş şifreli kopyalar silindi.
2. **Kestrel 28 MB body limit** → 413 Request Entity Too Large. Çözüm: Kestrel + FormOptions 250 MB.
3. **GoRouter redirect dialog'u pop'luyor** — `postFrameCallback`'te erken açılan dialog auth resolve'undan önceydi; auth listener içine taşındı + 400 ms delay.
4. **Flutter `split-per-abi` versionCode offset** — `base + abi*1000` formülü (arm64=2 → 2001, vb.) backend kaydındaki versionCode'la uyumsuzdu; cihaz testi için universal APK seçildi.

## Coolify kaynakları

- App env'de `ADMIN_TOKEN` set edildi (rotation: env_vars update + redeploy)
- `api_uploads` volume Coolify volumes listesinde yer alır (`vgvexxga7f7ah4puhujzkh60_api_uploads`)
- Auto-deploy webhook commit b4d7344'ten beri aktif — `git push` → ~30 s sonra prod'da

## Açık sorular / sonraki faza taşınanlar

- [ ] Eski version kayıtları/dosyaları temizleyen housekeeping job (saklamayı son 5 sürümle sınırla?)
- [ ] split-per-abi vs universal kararı — boyut/dağıtım trade-off (~30 MB arm64 vs ~42 MB universal); şimdilik universal
- [ ] Admin role + UI (kim hangi APK'yı yükledi audit log)
- [ ] HTTPS — sslip.io üzerinde Let's Encrypt çalışıyor mu? (kullanıcı şimdilik HTTP istedi)
- [ ] MinIO public erişim — chat media presigned URL akışı için (Storage adapter implementasyonu ile birlikte)
- [ ] Periodic version check — şu an sadece app startup; günde bir kez foreground check (workmanager?) eklenebilir
