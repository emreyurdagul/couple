# ADR-0006: Chat medyası — MinIO + presigned URL akışı

**Status:** Accepted
**Tarih:** 2026-05-10

## Context

Chat MVP'de **resim + ses notu** isteniyor. Üç akış mümkün:

1. Multipart upload sunucuya → sunucu S3'e yazar (en yavaş, bandwidth çift kullanır).
2. Presigned URL: sunucu URL üretir, client doğrudan storage'a yükler.
3. Direkt storage credential'ı client'a verme (güvensiz, asla yapma).

Storage tarafında: maliyet hassasiyeti var, kart vermek istemiyoruz → **self-hosted MinIO** (S3 uyumlu, Docker'da çalışır).

## Decision

- **Storage:** MinIO container (`docker-compose.yml`'de tanımlı), bucket: `couple-media`.
- **Akış:**
  1. Client `POST /media/presign` → `{contentType, sizeBytes}` gönderir.
  2. Server MIME/size validate eder + couple_id'ye göre object key üretir (`{coupleId}/{messageId}-{ext}`) → `{objectKey, putUrl, getUrl}` döner.
  3. Client `PUT putUrl` ile MinIO'ya **doğrudan** upload (sunucuyu by-pass).
  4. Client `POST /messages` → `{Type=Image|Voice, MediaObjectKey: objectKey, …}`.
- **Erişim kontrolü:** `getUrl` da presigned (örn. 7 gün TTL); MinIO bucket public değil. Client her seferinde fresh URL ister (`GET /media/{key}`) veya UUID v7 sıralılığı sayesinde cache'ler.
- **MIME whitelist (MVP):** `image/jpeg`, `image/png`, `image/webp`, `audio/mp4`, `audio/mpeg`, `audio/aac`. Size limit: resim 10 MB, ses 5 MB.
- **Lifecycle:** bucket policy 90 gün retention (soft); medya `Messages` satırı yaşadığı sürece korunur (silme cron'u sonra).

## Consequences

- ➕ Backend bandwidth tüketmez; ölçek için kritik.
- ➕ MinIO ücretsiz; AWS S3'e geçmek istersek SDK aynı, sadece endpoint değişir.
- ➕ Couple-scoped object key + presigned URL → başka couple'ın medyası tahmin edilse bile signature'sız erişilemez.
- ➖ Object lifecycle (silme) ile DB tutarlılığı: `Messages` silinirse object da silinmeli (outbox event ile yapılabilir).
- ➖ MinIO operasyonel: backup, disk dolma uyarısı, replication MVP'de yok (10-15 çift için ihtiyaç da yok).
- ➖ TLS: MinIO doğrudan internete açık olmamalı; Caddy arkasında reverse proxy ile servis edilir.
- 🔁 AWS S3'e geçiş: connection string + IAM credentials değişikliği; kod tarafı `Minio.Net SDK` zaten S3-uyumlu.

## Alternatives considered

- **AWS S3 doğrudan**: ücretli (kullanım az olsa da kart şart).
- **Cloudflare R2**: ücretsiz tier cömert, kart şart değil ama bağımsız hesap kurulumu MinIO'dan daha karmaşık erken aşamada.
- **Sunucudan stream**: backend bandwidth + bellek + 30s timeout sorunları.
- **Base64 mesaj payload'ında**: small icon ok, ama 10 MB resim Postgres satırına saçma.
