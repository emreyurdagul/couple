# İlerleme dizini

Her anlamlı iş bloğu için faz logu (`progress/NNN-*.md`) ve gerekirse mimari karar kaydı (`adr/NNNN-*.md`) eklenir. Detaylı sistematik için: `/home/emre/.claude/projects/.../memory/feedback_progress_tracking.md`.

## Faz logları

| # | Tarih | Konu | Durum |
|---|---|---|---|
| 001 | 2026-05-10 | [Çekirdek iskelet (backend + mobile + infra)](001-skeleton.md) | ✅ Tamamlandı |
| 002 | 2026-05-10 | [Auth + Couple davet](002-auth-and-invite.md) | 🟢 Backend yeşil + mobil iskelet hazır + cihazda doğrulanmış (defter dili UI ile) |
| 003 | 2026-05-10 → … | [Chat (metin + rich messages)](003-chat.md) | 🟢 Baseline + v2 merge'lendi; cihaz UX testi bekliyor |
| 004 | 2026-05-10 → 2026-05-11 | [Konum takibi](004-location.md) | 🟡 Phase 4a backend + 4b mobil kod tamam; cihaz UX testi bekliyor |
| 005 | 2026-05-11 | [APK release build optimizasyonu (Phase 4c)](005-apk-optimizasyon.md) | 🟢 Boyut 203 MB → 29.8 MB; release smoke test bekliyor |
| 006 | 2026-05-11 → 2026-05-12 | [Coolify production deploy (Phase 5a)](006-coolify-deployment.md) | 🟢 Yayında: `vgvexxga7f7ah4puhujzkh60.72.61.95.76.sslip.io` (HTTP/healthy) |

## Mimari Karar Kayıtları (ADR)

| # | Başlık | Durum |
|---|---|---|
| 0001 | [.NET 10 + Postgres/PostGIS + SignalR seçimi](../adr/0001-net10-postgis-signalr.md) | Accepted |
| 0002 | [Couple-scoped multi-tenancy stratejisi](../adr/0002-couple-scoping.md) | Accepted |
| 0003 | [Offline-first + outbox pattern](../adr/0003-offline-first-outbox.md) | Accepted |
| 0004 | [Soft-archive on breakup](../adr/0004-soft-archive-breakup.md) | Accepted |
| 0005 | [Harita: flutter_map + OpenStreetMap (Google Maps yerine)](../adr/0005-flutter-map-osm.md) | Accepted |
| 0006 | [Medya: MinIO presigned URL akışı](../adr/0006-minio-presigned.md) | Accepted |
| 0008 | [Konum takibi: paket, beraber-süre algoritması, retention](../adr/0008-location-tracking.md) | Accepted |
| 0009 | [APK release build optimizasyonu (R8 + ProGuard + split-per-abi)](../adr/0009-apk-release-optimizasyon.md) | Accepted |
| 0010 | [Production deploy — Coolify + Docker Compose (GitHub private)](../adr/0010-coolify-deployment.md) | Accepted |
