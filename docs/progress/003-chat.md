# 003 — Chat (metin)

**Tarih:** 2026-05-10
**Durum:** 🟢 Backend + mobile çalışan ilk sürüm cihazda; **kullanıcı UX testi bekleniyor**

## Hedef

Çiftler arası realtime metin mesajlaşma. Backend tarafında SignalR `ChatHub` + REST fallback (`POST /messages`) + history pagination (`GET /messages`). Mobil tarafında defter dilinde chat ekranı, ben/sen perspektifli mesaj balonları, optimistic send.

## Adımlar

- [x] Backend: `IMessageService` (UpsertAsync, ListAsync, MarkReadAsync) — idempotent UUIDv7 upsert
- [x] Backend: `ChatHub` geliştirildi — OnConnect couple grubuna ekler, `SendMessage` server persist + grup broadcast, `MarkRead` + `Typing` event'leri
- [x] Backend: REST endpoint'ler — `POST /messages` (Hub kapalıyken fallback), `GET /messages?since={cursor}&take=N`, `POST /messages/{id}/read`
- [x] Backend: REST endpoint'ten gönderim de SignalR group'a broadcast ediyor (Hub kapalı senaryoda da partner cihazları realtime alır)
- [ ] Backend: Outbox event "MessageCreated" — partner offline ise FCM push (Phase 3.2 / Phase 4 başında)
- [x] Mobil: `ChatRepository` (REST history + send + markRead) + `ChatSignalrClient` (singleton, reconnect, ReceiveMessage/MessageRead/Typing handlers)
- [x] Mobil: `ChatController` (Riverpod, message list state, optimistic send, incoming dedup)
- [x] Mobil: `ChatScreen` — defter dili, mesaj balonları (ben sağ-stamp, partner sol-paperDeep), input bar, gün ayraçları, delivery/okundu indikatörü, typing hint, bağlantı durumu
- [x] Mobil: Home "Mesajlar" stream card → /chat yönlendirme
- [ ] Drift ile offline queue + sync engine (Phase 3.1, sonradan)
- [ ] Cihazda manuel test — kullanıcı UX onayı bekleniyor

## Kararlar

- **Idempotency**: client `Id` (UUIDv7) zorunlu. Server upsert (varsa update, yoksa insert).
- **Group strategy**: `couple:{coupleId}` SignalR group. OnConnect'te add, OnDisconnect otomatik temizlenir.
- **Echo policy**: SendMessage çağrısı sender'a server-confirmed mesajı **return** eder (clientside replace tempId), partnere `Clients.OthersInGroup` ile push edilir → çift mesaj görünmez.
- **Auth**: hub query string `?access_token=` zaten desteklendi (Program.cs'te JwtBearerEvents).
- **Couple-scope filter**: ChatHub'a bağlanırken `couple_id` claim zorunlu — yoksa `Context.Abort()`.
- **Mesaj limiti (MVP)**: tek mesaj max 4000 karakter, `Messages.Content` kolon limiti.

## Eklenen / Değişen dosyalar

### Backend
- `src/Couple.Domain/Abstractions/IMessageService.cs` (yeni) + `MessageInput`
- `src/Couple.Infrastructure/Messaging/MessageService.cs` (yeni)
- `src/Couple.Infrastructure/DependencyInjection.cs` (IMessageService DI)
- `src/Couple.Api/Hubs/ChatHub.cs` — `Hub<IChatClient>`, OnConnect couple grup, SendMessage/MarkRead/Typing
- `src/Couple.Api/Endpoints/MessageDto.cs` (yeni)
- `src/Couple.Api/Endpoints/MessageEndpoints.cs` (yeni — POST/GET /messages, POST /{id}/read)
- `src/Couple.Api/Program.cs` (MapMessageEndpoints)

### Mobile
- `lib/features/chat/data/message_models.dart` (Message, MessageType, DeliveryStatus)
- `lib/features/chat/data/chat_repository.dart` (REST + UUIDv7 newId)
- `lib/features/chat/data/chat_signalr_client.dart` (HubConnection wrapper, broadcast streams)
- `lib/features/chat/state/chat_controller.dart` (Riverpod, list+send+receive+typing)
- `lib/features/chat/presentation/chat_screen.dart` (defter dili UI)
- `lib/core/config/app_router.dart` (`/chat` route)
- `lib/features/home/presentation/home_screen.dart` (Mesajlar kartı tap handler)
- `lib/main.dart` (`initializeDateFormatting('tr')`)

## Doğrulama

```bash
# Backend
dotnet build && dotnet run --no-build &
# REST smoke
docs/progress/scripts/chat-rest-smoke.sh
# Mobile
flutter test
flutter build apk --debug && adb install -r ...
```

### Kullanıcı doğrulaması gerekli

**Ön hazırlık:** cihazda mevcut session aktif bir couple'a sahip olmalı. (Önceki testte alice@/bob@ couple'ı soft-archive edildi; smoke script alice2/bob2 gibi fresh hesaplar oluşturdu.) Cihazda yeni couple kurmak için:
- Mevcut Login ekranında **alice2-XXX@example.com / Password123** ile giriş yap (smoke script'in son ürettiği eposta — script çıktısına bak)
- VEYA Logout → yeni hesap aç → davet üret → ikinci hesap için curl ile davet kabul et:
  ```bash
  TOKEN=$(curl -sS -X POST $BASE/auth/login -H 'Content-Type: application/json' \
    -d '{"email":"...","password":"Password123"}' | jq -r .accessToken)
  curl -sS -X POST $BASE/couples/invites/CODE/accept -H "Authorization: Bearer $TOKEN"
  ```

**Test senaryosu:**

1. Home → "Mesajlar" kartına tıkla → chat ekranı açılmalı (boş ise "İlk satırı sen yaz" mesajı, varsa history)
2. Alt input'a yaz, ⬆ butonuna bas → mesaj sağda terra cotta balonu olarak görünmeli (clock ikonu → tik)
3. Sunucudan partner adına curl ile mesaj gönder:
   ```bash
   curl -sS -X POST $BASE/messages \
     -H "Authorization: Bearer <PARTNER_TOKEN>" -H "Content-Type: application/json" \
     -d '{"id":"'$(uuidgen)'","type":0,"content":"selam canım"}'
   ```
   → cihaza realtime gelmeli, sol kâğıt balonu olarak görünmeli (SignalR yoluyla)
4. Mesaj göndermek istediğinde uçak modu aç → "Sunucuya bağlanılamadı" → mesaj kırmızı `!` ikonu ile failed (Drift entegrasyonu Phase 3.1)
5. Bağlantı kopukken `/chat` ekranını aç → header'da kırmızı refresh ikonu → tıkla → connecting → connected
6. Geri butonu → Home'a dönmeli

#### Bilinen kısıtlar (bu fazda)

- Failed mesaj retry yok (Phase 3.1 — Drift offline queue)
- Push notification yok — partner offline iken bildirim gelmez (Phase 3.2 — FCM)
- Mesaj edit/delete yok (v2)

## Açık sorular / sonraki faza taşınanlar

- [ ] Drift offline queue (3.1)
- [ ] FCM push (3.2 veya Phase 4 başı) — Firebase project, google-services.json gerekiyor
- [ ] Mesaj reactions, edit, delete (v2)
