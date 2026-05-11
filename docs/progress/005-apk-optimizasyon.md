# 005 — APK Release Build Optimizasyonu (Phase 4c)

**Tarih:** 2026-05-11
**Durum:** 🟢 Kod tamam + boyut hedefe ulaştı; cihazda smoke test bekliyor

## Hedef

Debug APK 203 MB → release split APK ~30 MB seviyesine indirgemek. Phase 5 in-app update akışından önce dağıtım boyutunu makul hale getirmek.

## Kararlar

- Release `isMinifyEnabled = true` + `isShrinkResources = true` → ADR-0009
- `proguard-android-optimize.txt` (default optimize set) + özel `proguard-rules.pro` → ADR-0009
- `flutter build apk --release --split-per-abi` ile ABI ayrımı → her cihaz kendine uygun APK'yı indirir
- `signingConfig = debug` korundu; Phase 5'te kendi keystore'a geçilecek

## Eklenen / Değişen dosyalar

- `mobile/couple_app/android/app/build.gradle.kts` — release buildType'a minify + shrinkResources + proguardFiles eklendi
- `mobile/couple_app/android/app/proguard-rules.pro` — yeni; Flutter, workmanager, flutter_foreground_task, geolocator, drift/sqlite3, mobile_scanner/ML Kit, permission_handler için conservative keep kuralları + attribute koruması + SourceFile/LineNumberTable
- `docs/adr/0009-apk-release-optimizasyon.md` — ADR
- `docs/progress/INDEX.md` — 005 satırı + ADR-0009 satırı eklendi

## Doğrulama

```bash
flutter build apk --release --split-per-abi
```

Sonuç:

| APK | Boyut |
|---|---|
| `app-debug.apk` (eski) | **203 MB** |
| `app-arm64-v8a-release.apk` | **29.8 MB** (-85%) |
| `app-armeabi-v7a-release.apk` | 26.0 MB |
| `app-x86_64-release.apk` | 32.3 MB |

- ✅ Gradle `assembleRelease` 204 s'de temiz tamamlandı
- ✅ Font asset tree-shake otomatik: MaterialIcons 1.6 MB → 5 KB (%99.7), CupertinoIcons 257 KB → 848 B (%99.7)
- ⚠️ Java 8 source/target obsolete uyarısı — Flutter Gradle plugin'inden geliyor, bu fazda dokunmuyoruz
- ⚠️ R8 minify cihazda runtime hatasına yol açabilir; smoke test şart

## Kullanıcı doğrulaması gerekli (Phase 4c için)

Release APK'yı cihaza yükleyip aşağıdaki akışları doğrula. Herhangi biri kırılırsa ilgili paketi `proguard-rules.pro`'ya keep olarak ekle:

- [ ] Uygulama açılış + auth (login/refresh)
- [ ] Davet QR (qr_flutter üretme) + QR tarama (mobile_scanner / ML Kit)
- [ ] Chat: mesaj gönder/al, reaction, reply, edit, delete (SignalR + Drift)
- [ ] Konum: izin akışı → foreground service notification → /map ekranı (flutter_map + polyline + "biz" imleci)
- [ ] Background: 15dk workmanager fallback ping (uygulama kapalıyken konum gönderimi)
- [ ] Bildirim çubuğunda foreground service notification metni görünür

## Açık sorular / sonraki faza taşınanlar

- [ ] Phase 5: kendi release keystore + `key.properties` yönetimi
- [ ] Phase 5: Backend'de `/api/version/latest` + APK barındırma + install_plugin akışı
- [ ] Eğer cihaz testinde paket kırılırsa proguard-rules.pro genişletilecek
