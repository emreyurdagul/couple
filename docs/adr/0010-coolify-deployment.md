# ADR-0010: Production deploy — Coolify + Docker Compose (GitHub private)

**Status:** Accepted
**Tarih:** 2026-05-11

## Context

Phase 4 sonunda backend (`Couple.Api`) + Postgres/PostGIS + MinIO stack'i lokal dev'de (`infra/docker-compose.yml`, Caddy + host portları) çalışıyor. Production'a çıkmak için bir host + reverse proxy + TLS + sürekli deploy çözümü gerekiyor.

Kısıtlar:

- Dev makinesi Fedora 44 + Podman (rootless, Docker yok). Build artefact üretip registry'ye push'lamak ek altyapı gerektirir.
- Coolify sunucusu zaten kurulu (`host.docker.internal`, "localhost" sunucusu). Coolify kendi Traefik proxy'sini, TLS'sini, env-var yönetimini ve git-tabanlı build pipeline'ını sağlıyor.
- Kod kapalı tutulmak isteniyor (private repo).

## Decision

**Coolify, "Docker Compose" build pack'iyle private GitHub repo'sundan deploy edecek.**

- Yeni `infra/docker-compose.coolify.yml` dosyası: lokal dev compose'undan ayrı, Caddy ve host port mapping içermez. Coolify Traefik kendi yönlendirir.
- API service'inde `SERVICE_FQDN_API_8080` magic env değişkeni — Coolify otomatik FQDN üretir, Traefik etiketlerini ekler, port 8080'e route'lar.
- Backend `Program.cs` başlangıçta `db.Database.MigrateAsync()` çağırıyor → ilk deploy'da PostGIS şeması otomatik kurulur (postgis extension `HasPostgresExtension` annotation'ı ile gelir).
- `UseForwardedHeaders` middleware'i Coolify proxy'sinin X-Forwarded-Proto/For header'larına güvenecek şekilde yapılandırıldı (SignalR ws upgrade ve HTTPS scheme tespiti için kritik).
- Coolify "Custom GitHub App" — Public GitHub OAuth değil, private repo erişimi için kullanıcı tek seferlik App register edecek.

Compose servisleri:

| Servis | İmaj | Public? | Volume |
|---|---|---|---|
| postgres | postgis/postgis:16-3.4 | sadece internal | postgres_data |
| minio | minio/minio:latest | sadece internal (ileride presigned için public hale getirilebilir) | minio_data |
| api | local build (`backend/Dockerfile`) | Coolify FQDN üzerinden | — |

## Consequences

- ➕ Tek bir compose dosyası push'la deploy → infra-as-code, geri alınabilir.
- ➕ Coolify TLS sertifikalarını otomatik (Let's Encrypt) yönetir.
- ➕ DB migrate startup'ta otomatik → her deploy sonrası manuel adım yok.
- ➕ Lokal dev compose etkilenmedi (`infra/docker-compose.yml` Caddy + host port mapping ile aynen kalır).
- ➖ İlk Coolify-GitHub App register'ı manuel (Coolify UI → Sources → GitHub App → GitHub'da register/install). Bu tek seferlik, sonradan tekrar gerekmez.
- ➖ Migrate-on-startup tek replica için güvenli; horizontal scale'e geçilirse advisory lock veya ayrı migrate job'ı düşünmek gerek.
- 🔁 Birden çok ortam (staging) eklenecekse: Coolify aynı projede yeni environment + ayrı branch'lerden deploy.

## Alternatives considered

- **Coolify managed PostgreSQL + ayrı Application (API)** — managed DB Coolify UI'dan otomatik backup almak için cazip ama PostGIS extension'lı imaj seçimi sınırlı, compose içinde tek stack tutmak daha temiz.
- **Önceden build edilmiş Docker imajı (ghcr/dockerhub)** — registry işletmek ve Podman'dan push'lamak (rootless OCI workflow) ek karmaşıklık. Coolify'ın git-build pipeline'ı bunu yutuyor.
- **Public GitHub OAuth ile public repo** — kod kapalı kalmıyor, ek güvenlik riski.
- **VPS'e SSH + manuel docker-compose** — TLS, env-var yönetimi, log monitoring kendi başına; Coolify hepsini bedavadan veriyor.
