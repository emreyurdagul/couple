# 006 — Coolify production deploy (Phase 5a)

**Tarih:** 2026-05-11 → 2026-05-12
**Durum:** 🟢 Yayında — http://vgvexxga7f7ah4puhujzkh60.72.61.95.76.sslip.io/ (`/`, `/health/live`, `/health/ready` hepsi 200)

## Hedef

Backend API'yi Coolify sunucusunda yayına almak. Lokal dev compose'unu bozmadan, paralel bir "production-ready" compose hazırlamak; deploy pipeline'ı git push tetiklemeli olacak.

## Kararlar

- Yeni `docker-compose.yaml` (repo root) — Caddy yok, host port yok, Coolify Traefik proxy → ADR-0010
- `SERVICE_FQDN_API_8080` magic env → Coolify otomatik FQDN + Traefik labels → ADR-0010
- `Program.cs` startup'ta `db.Database.MigrateAsync()` — ilk deploy'da şema + postgis extension otomatik kurulur → ADR-0010
- `UseForwardedHeaders` middleware — Coolify proxy'sinin `X-Forwarded-*` header'larına güven (SignalR ws + HTTPS scheme tespiti)
- Coolify "Custom GitHub App" — private repo erişimi için tek seferlik kullanıcı setup'ı (Public GitHub OAuth yeterli değil)

## Eklenen / Değişen dosyalar

- `docker-compose.yaml` (repo root) — yeni; Coolify-uyumlu production compose (postgres, minio, api; Caddy ve host port yok)
- `backend/src/Couple.Api/Program.cs` — startup migration + UseForwardedHeaders eklendi
- `docs/adr/0010-coolify-deployment.md` — ADR
- `docs/progress/INDEX.md` — 006 satırı + ADR-0010 satırı eklendi (sonraki commit'te)
- Coolify: yeni proje "couple" (`mgp1dxymzr2mzuc75gpbs63z`) + "production" env (`rvgfpebjefceblb7grueeedm`)

## Doğrulama

```bash
dotnet build src/Couple.Api/Couple.Api.csproj -c Release
```

- ✅ Build temiz (0 hata, sadece NU1903 pre-existing güvenlik uyarıları — bu fazda dokunulmadı)
- ✅ Coolify projesi MCP üzerinden oluşturuldu

## Karşılaşılan sorunlar ve düzeltmeler

1. **`wget` runtime image'da yok** → `aspnet:10.0` slim Debian image'inde wget yok, Dockerfile HEALTHCHECK fail veriyordu (`unhealthy`). Çözüm: runtime stage'e `apt-get install curl libgssapi-krb5-2`, healthcheck `curl -fsS`'e geçildi (commit `b4038d2`).
2. **Coolify Traefik routing 404** → Application'da `ports_exposes` 80'di; 8080'e güncellendi ama Coolify dockercompose buildpack'inde `custom_labels` UI alanı ve `SERVICE_FQDN_API_8080` magic env Traefik etiketlerini compose'a yansıtmıyor (sadece `coolify.*` etiketleri geliyor). Çözüm: Traefik etiketlerini doğrudan `docker-compose.yaml`'daki api servisine `labels:` bloğunda tanımladık (commit `3ef11cc`). Bu deneyim memory'ye eklendi (`feedback_coolify_compose_labels.md`).
3. **Env var duplicate'ları** → İlk app create'inde paralel POST attempt'lerinden 2 set env var oluştu (bir set boş şifrelerle). Boş duplicate'lar silindi, ilk set gerçek değerlerle update'lendi.

## Doğrulama (production)

```bash
curl http://vgvexxga7f7ah4puhujzkh60.72.61.95.76.sslip.io/
# {"name":"Couple API","version":"0.1.0"}

curl http://vgvexxga7f7ah4puhujzkh60.72.61.95.76.sslip.io/health/live
# Healthy

curl http://vgvexxga7f7ah4puhujzkh60.72.61.95.76.sslip.io/health/ready
# Healthy (postgres bağlı, migration uygulandı)
```

## Coolify kaynakları

- Project: `couple` (UUID `mgp1dxymzr2mzuc75gpbs63z`) / Environment: `production` (`rvgfpebjefceblb7grueeedm`)
- Application: `couple-api` (UUID `vgvexxga7f7ah4puhujzkh60`)
- Server: localhost (`zuu7m54x8wklq817bgksjumf`, IP `72.61.95.76`)
- GitHub source: `emreyurdagul/couple` (private), branch `master`, GitHub App `emrecoolify` (`t132xak4reuu5l7p07q2zxiy`)

## Açık sorular / sonraki faza taşınanlar

- [ ] MinIO public erişim (medya presigned URL akışı için `SERVICE_FQDN_MINIO_9000` eklenecek mi?) — `docker_compose_domains` UI'dan set edilebilir veya benzer Traefik label injection.
- [ ] Mobile app `apiBaseUrl` Coolify FQDN'sine geçiş (Phase 5b) — `mobile/couple_app/lib/.../api_base_url.dart` (varsa) güncelle, cihazda login + chat + konum akışını doğrula.
- [ ] Custom domain (örn. `api.couple.<senin-domain>`) — DNS kayıtları + compose'daki Traefik Host(...) etiketi güncelle, Let's Encrypt için `entryPoints=https` ve `certresolver=letsencrypt` ekle.
- [ ] Backup/restore stratejisi: Postgres volume snapshot otomatize (Coolify backup özelliği veya cron + restic).
- [ ] Production tekrar deploy edileceğinde `JWT_SECRET` rotation prosedürü dokumante edilsin (mobile login token'ları invalidate olur).
