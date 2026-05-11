# 006 — Coolify production deploy hazırlığı (Phase 5a)

**Tarih:** 2026-05-11
**Durum:** 🟡 Dosyalar hazır; GitHub repo + Coolify App kurulumu kullanıcıda; Coolify Application oluşturma ve deploy bekliyor

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

## Kullanıcı tarafında bekleyen adımlar

- [ ] `gh auth login` (interaktif)
- [ ] Private repo oluştur (`couple`) + master branch push
- [ ] Coolify UI → Sources → Custom GitHub App register/install (tek sefer)
- [ ] Repo URL + GitHub App UUID'sini paylaş → Coolify Application MCP ile oluşturulur, deploy tetiklenir

## Deploy doğrulaması (Application oluştuktan sonra)

- [ ] Coolify build log → SDK 10.0 image pull + publish başarılı
- [ ] `/` → `{name: "Couple API", version: "0.1.0"}`
- [ ] `/health/live` → 200
- [ ] `/health/ready` → 200 (postgres bağlı)
- [ ] Postgres logs'unda `postgis` extension oluştu, migration table'lar görünüyor
- [ ] Mobile app `apiBaseUrl`'ünü Coolify FQDN'sine güncelle, login akışını cihazda test et

## Açık sorular / sonraki faza taşınanlar

- [ ] MinIO public erişim (medya presigned URL akışı için `SERVICE_FQDN_MINIO_9000` eklenecek mi?)
- [ ] Coolify Application oluşturma + env var seed (POSTGRES_PASSWORD, JWT_SECRET vb.) MCP üzerinden tamamlanacak
- [ ] Mobile app build config — `apiBaseUrl` Coolify FQDN'sine geçiş (Phase 5b)
- [ ] Backup/restore stratejisi: postgres volume snapshot otomatize?
