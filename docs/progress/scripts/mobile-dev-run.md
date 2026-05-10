# Mobil dev: lokal cihaz/emülatörde çalıştırma

## 1. API'yi başlat (host makinede)

```bash
# postgres + (sonra) minio + caddy
cd /home/emre/Masaüstü/COUPLE/infra
podman-compose up -d postgres

# .NET API
cd /home/emre/Masaüstü/COUPLE/backend/src/Couple.Api
dotnet run --no-build
# Listening on http://localhost:5049
```

## 2. Mobil uygulamayı başlat

### Android emülatörde

Android emülatörü 10.0.2.2'yi host loopback olarak görür. `pubspec.yaml`'da
`AppConfig.apiBaseUrl` defaultu zaten `http://10.0.2.2:8080`; ama API
default 5049'da koşuyor. Override:

```bash
cd /home/emre/Masaüstü/COUPLE/mobile/couple_app
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:5049
```

### Fiziksel Android cihazda (USB/WiFi)

1. Bilgisayarın WiFi IP'sini bul: `ip -4 addr show | grep inet`
2. API'yi `0.0.0.0`'a aç:
   ```bash
   ASPNETCORE_URLS=http://0.0.0.0:5049 dotnet run --no-build
   ```
3. Cihazı aynı ağa bağla, çalıştır:
   ```bash
   flutter run \
     --dart-define=API_BASE_URL=http://192.168.X.X:5049
   ```
4. Plain HTTP kullanıyoruz; Android'de `usesCleartextTraffic="true"` izninin
   AndroidManifest.xml'de aktif olması gerekir (Phase 5'te HTTPS'e geçince
   kapatılır).

### iOS simulator (macOS gerek)

```bash
flutter run \
  --dart-define=API_BASE_URL=http://localhost:5049
```

## 3. Test akışı (manuel)

1. Cihaz/emülatör 1 → "Kayıt ol" → e-posta, parola, ad → Onboarding ekranına geç
2. "Davet kodu oluştur" → 6 haneli kod ve QR görünmeli
3. Cihaz/emülatör 2 → "Kayıt ol" (farklı e-posta) → Onboarding
4. "Partner kodunu gir / QR tara" → kodu yaz veya QR'a tut
5. "Eşleş" → Home ekranına yönlendirilmeli, partnerin adı görünmeli
6. Cihaz 1'e geri dön → Home ekranı + partner adı (cihaz 1 access token'ı yenilemese de
   `/couples/me` IgnoreQueryFilters kullandığı için backend'den partner görünür)
7. Üst sağ "kalp kırığı" ikonu → "Sonlandır" → her iki cihaz Login ekranına dönmeli

## Bilinen kısıtlar (Phase 2 sonu)

- Bağlantı kayıpları için offline-first henüz devrede değil (Phase 3).
- FCM push, ses notu, harita: sonraki fazlar.
- iOS gerekli platform-spesifik izin tanımları henüz Info.plist'te yok
  (kamera için QR scanner için mobile_scanner gerektirebilir;
  manuel kod girişi her durumda çalışır).
