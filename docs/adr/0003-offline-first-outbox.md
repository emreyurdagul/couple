# ADR-0003: Offline-first istemci + Outbox pattern (server)

**Status:** Accepted
**Tarih:** 2026-05-10

## Context

Kullanıcı "altyapı/kod her zaman girilebilir olmalı" istedi (üçü birden: offline-first + uptime + extensible). Mobil senaryoda bağlantı kayıpları (metro, asansör, uçak modu) yaygın; kullanıcı yazdığı mesajın "Gönderiliyor…" diye sonsuz takılmasını istemez.

Ayrıca server tarafında: yeni mesaj veya konum yazıldığında karşı tarafa push notification göndermek dış servis (FCM) çağrısı gerektirir; bu çağrı başarısız olursa DB transaction commit olmuş ama bildirim gitmemiş olabilir → tutarsızlık.

## Decision

**İstemci tarafı (Flutter):**
- Drift (SQLite) yerel veritabanı; tüm mesaj/konum/takvim yazımları **önce yerel DB'ye** yazılır.
- Outbox kuyruğu (yerel tablo): pending senkronizasyon kayıtları; bağlantı dönünce sırayla server'a iter.
- ID'ler **UUID v7** ile client tarafında üretilir → server upsert idempotent.
- Sync engine: `GET /sync?since={cursor}` ile server'dan delta çeker.

**Server tarafı (.NET):**
- `OutboxEvent` tablosu: `(AggregateType, AggregateId, EventType, Payload jsonb, CreatedAt, DispatchedAt, Attempts)`.
- Domain işlemi yazma + outbox kayıt **aynı DB transaction'ında** (`SaveChanges` tek seferde).
- `OutboxDispatcher : BackgroundService` 2 saniyede bir 32'lik batch çeker, dış efektleri (FCM push, partner SignalR mesajı) çalıştırır, başarılı olunca `DispatchedAt` set eder.
- `IOutboxPublisher.EnqueueAsync` API → endpoint kodları FCM'i doğrudan çağırmak yerine outbox'a yazar.

## Consequences

- ➕ Mesaj/konum yazma latency'si DB write süresi; dış servis gecikmesi kullanıcıya yansımaz.
- ➕ Push notification %100 at-least-once garantili (DB'ye yazıldıysa eninde sonunda gider).
- ➕ İstemci offline'dayken kullanıcıya hiçbir hata gösterilmez; UI optimistic.
- ➕ FCM/MinIO/etc. servisi kısa süreli düşse bile veri kaybı yok.
- ➖ Outbox dispatcher monitoring (kuyruk birikmesi alarmı) eklenmeli; aksi halde sessiz birikim olabilir.
- ➖ İdempotency disiplini: server endpoint'leri client-side `Id` ile upsert yapmak zorunda; aksi halde retry'da çift kayıt.
- ➖ Drift schema migration mobil tarafta dikkat ister (aksi halde eski cihazlardan veri kaybı).
- 🔁 Outbox kalkıp doğrudan handler'a geçmek tek satırlık değişiklik değil; 1-2 günlük refactor.

## Alternatives considered

- **Synchronous side-effects** (yazma sırasında FCM çağrısı): basit ama %100 hata garanti yok.
- **Message broker** (RabbitMQ/Kafka): outbox + tüketici ayırımı; MVP için aşırı operasyonel maliyet.
- **Eventually consistent server, no outbox**: client retry'a yaslanmak; client kontrolünden çıkan bildirimler için yetersiz.
