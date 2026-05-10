# İlerleme dizini

Her anlamlı iş bloğu için faz logu (`progress/NNN-*.md`) ve gerekirse mimari karar kaydı (`adr/NNNN-*.md`) eklenir. Detaylı sistematik için: `/home/emre/.claude/projects/.../memory/feedback_progress_tracking.md`.

## Faz logları

| # | Tarih | Konu | Durum |
|---|---|---|---|
| 001 | 2026-05-10 | [Çekirdek iskelet (backend + mobile + infra)](001-skeleton.md) | ✅ Tamamlandı |
| 002 | 2026-05-10 → … | [Auth + Couple davet](002-auth-and-invite.md) | 🟡 Devam ediyor |

## Mimari Karar Kayıtları (ADR)

| # | Başlık | Durum |
|---|---|---|
| 0001 | [.NET 10 + Postgres/PostGIS + SignalR seçimi](../adr/0001-net10-postgis-signalr.md) | Accepted |
| 0002 | [Couple-scoped multi-tenancy stratejisi](../adr/0002-couple-scoping.md) | Accepted |
| 0003 | [Offline-first + outbox pattern](../adr/0003-offline-first-outbox.md) | Accepted |
| 0004 | [Soft-archive on breakup](../adr/0004-soft-archive-breakup.md) | Accepted |
| 0005 | [Harita: flutter_map + OpenStreetMap (Google Maps yerine)](../adr/0005-flutter-map-osm.md) | Accepted |
| 0006 | [Medya: MinIO presigned URL akışı](../adr/0006-minio-presigned.md) | Accepted |
