# ADR-0001: .NET 10 + PostgreSQL/PostGIS + SignalR

**Status:** Accepted
**Tarih:** 2026-05-10

## Context

Mobil-öncelikli çift uygulamasının backend'i için runtime, DB ve realtime katmanını seçmemiz lazım. Kritik özellikler chat ve **arka plan konum paylaşımı** (geospatial sorgular gerektirir). Kullanıcı .NET tercih etti ve sürümü 10 olarak istedi.

## Decision

- **Runtime:** ASP.NET Core 10 (Web API + SignalR + BackgroundService).
- **DB:** PostgreSQL 16 + **PostGIS** extension. Tek veritabanı; Redis MVP'de yok.
- **ORM:** EF Core 10 + Npgsql + NetTopologySuite (PostGIS `Point` doğrudan map).
- **Realtime:** SignalR (hem chat hem konum için tek pipeline).

## Consequences

- ➕ Tek runtime + tek DB → operasyonel basitlik (10-15 çiftlik ölçek için yeterli).
- ➕ PostGIS ile mesafe/polygon sorguları (sonraki faz konum-tabanlı oyunlar için) hazır.
- ➕ SignalR Flutter tarafında `signalr_netcore` ile çalışıyor; ek protokol katmanı yok.
- ➖ Anlık konum yayını yüksek frekansta → tek API replikası ile başlıyoruz; ölçek büyürse Redis backplane + sticky session gerekecek.
- ➖ EF Core 10 yeni; bazı paketler hâlâ 9.x bağımlılığı taşıyor (NU1903 uyarısı).
- 🔁 Geri dönmek istersek: Postgres'i bırakmadan SignalR'ı MQTT'ye, NetTopologySuite'i custom mapping'e değiştirebiliriz; ama EF Core'a bağımlı kod tabanını değiştirmek pahalı.

## Alternatives considered

- **MQTT broker** (EMQX/Mosquitto): konum için ideal ama chat için ek topic katmanı + .NET köprüsü. Tek kullanıcı senaryosu için aşırı karmaşık.
- **Firebase Firestore + FCM**: hazır chat/presence ama .NET backend ile çift veri kaynağı, vendor lock-in.
- **SQL Server**: .NET ile native ama lisans/maliyet ve PostGIS muadili (geography type) daha kısıtlı.
