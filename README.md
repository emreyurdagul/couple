# Couple

Çiftlere yönelik mobil-öncelikli uygulama. Tech stack: **.NET 10 + Flutter + PostgreSQL/PostGIS + SignalR + MinIO**.

## MVP

- E-posta/parola ile kayıt + JWT auth
- 6 haneli kod / QR ile çift davet ve eşleşme
- Realtime chat (metin + resim + ses notu) — offline-first
- Arka plan konum paylaşımı + son 24 saat iz (harita üstü polyline)

Detaylı mimari: bkz. `/home/emre/.claude/plans/imdi-benim-bir-ift-woolly-crab.md`.

## Repo

```
backend/    .NET 10 solution (Api + Domain + Infrastructure)
mobile/     Flutter projesi (couple_app)
infra/      docker-compose, Caddy
docs/adr/   Mimari karar kayıtları
```

## Geliştirme önkoşulları

- .NET 10 SDK
- Flutter (stable)
- PostgreSQL 16+ + PostGIS extension (lokal veya Docker)
- (İleride) Docker + Docker Compose
- (İleride) MinIO (Docker ile gelir)
