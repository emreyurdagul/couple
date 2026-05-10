# ADR-0005: flutter_map + OpenStreetMap (Google Maps yerine)

**Status:** Accepted
**Tarih:** 2026-05-10

## Context

Kullanıcı 10-15 çiftlik erken aşamada **kredi kartı vermek istemiyor**, "minimal ücretler kabul edilebilir". Harita iki yerde gerekli:
1. Partnerin canlı konumunu göstermek (anlık marker).
2. Son 24 saat polyline'ı (offline okumalar dahil).

Konum **toplama** (`flutter_background_geolocation`) harita kütüphanesinden bağımsız.

## Decision

- **Görselleştirme:** `flutter_map` (açık kaynak, MIT).
- **Tile sağlayıcı:** OpenStreetMap üstü **Stadia Maps free tier** (200k tile/ay, kart gerekmez).
- **Konum toplama:** `flutter_background_geolocation` (haritadan bağımsız; Google Maps olmadan da çalışır).
- Polyline çizimi: `flutter_map` `PolylineLayer` ile son 24 saat noktalarından.

## Consequences

- ➕ Sıfır maliyet, kart yok.
- ➕ Vendor lock-in yok.
- ➕ Konum toplama haritadan ayrık olduğu için gelecekte Google Maps'e geçiş **yalnızca harita widget'ını** değiştirir.
- ➖ Tile estetiği Google Maps kadar olgun değil (özellikle Türkiye'de bazı küçük kasaba detayları); MVP için yeterli.
- ➖ Stadia Maps free tier limitini aşarsak (10-15 çift için imkânsız ama 1000+ kullanıcıda olabilir) ya ücretli plan ya da kendi tile sunucusu (büyük ek iş).
- ➖ flutter_map'in aktif geliştirme hızı Google Maps SDK'ye göre yavaş.
- 🔁 Google Maps'e geçiş: `pubspec.yaml`'a `google_maps_flutter` ekle, harita widget'larını değiştir, billing kart kur. Konum/sync kodu hiç değişmez.

## Alternatives considered

- **Google Maps**: $200/ay free credit (10-15 çift için bol bol yeter) ama billing kart şartı var.
- **Mapbox**: Ücretsiz tier var, kart şartı yok ama Flutter SDK'sı Google kadar olgun değil + free tier limiti daha sıkı.
- **Self-hosted OSM tile server**: hiç maliyet yok ama VPS'te 50+ GB disk + render katmanı; MVP için aşırı.
