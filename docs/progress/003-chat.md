# 003 — Chat (metin + rich messages)

**Tarih:** 2026-05-10
**Durum:** 🟢 Baseline + v2 (rich messages) merge'lendi (`f881e15`); **kullanıcı UX testi bekleniyor** (hem baseline hem v2 için)

> Bu dosya iki alt-aşamayı kapsar:
> - **Baseline (commit `2dc40b8`)** — metin gönder/al, SignalR + REST, history, defter dili UI
> - **v2 — Rich messages (commit `f881e15`)** — reactions, reply, edit (15 dk pencere), delete (ForMe / ForBoth)
>
> Pin / TTL / ephemeral kolonları schema'da yer aldı ama endpoint + UI sonraki adımda.

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

---

# v2 — Rich messages

**Tarih:** 2026-05-10
**Commit:** `f881e15`
**Durum:** 🟡 Kod merge'lendi, build + analyze temiz; cihazda UX testi bekleniyor

## Hedef

Baseline metin chat'in üstüne çiftin günlük kullanımda beklediği "sosyal" davranışları kondurmak: alıntılayarak yanıtlama, emoji reaksiyonu, gönderenin son anda mesajını düzeltebilmesi, ve mesajı yalnız kendinden ya da iki taraftan da silebilmesi. Sahne arkasında pin / TTL / "anlık fotoğraf" için schema da hazırlandı; ama bu PR onların endpoint + UI'ını içermiyor.

## Adımlar

- [x] Backend: `MessageReaction` + `MessageDeletedForUser` entity'leri
- [x] Backend: Migration `AddRichMessages` — `Messages` tablosuna `EditedAt`, `DeletedAt`, `DeletedByUserId`, `IsPinned`, `PinnedAt`, `ExpiresAt`, `IsEphemeral`, `ViewedAt`, `ReplyToMessageId` + ilgili index'ler; iki yeni tablo (unique `(MessageId, UserId, Emoji)` ve `(MessageId, UserId)`)
- [x] Backend: `IMessageService` genişletildi — `AddReactionAsync` (idempotent), `RemoveReactionAsync`, `EditAsync` (sender + 15 dk), `DeleteAsync(scope)`, `GetAsync`; `ListAsync` artık `MessageWithReactions` döner ve "for me" silinmişleri çağıran kullanıcıdan gizler
- [x] Backend: REST — `PATCH /messages/{id}`, `DELETE /messages/{id}?scope=for_me|for_both`, `POST /messages/{id}/reactions`, `DELETE /messages/{id}/reactions/{emoji}`
- [x] Backend: ChatHub — `SendMessage` payload'una `ReplyToMessageId`; yeni `IChatClient` event'leri: `MessageReacted`, `MessageReactionRemoved`, `MessageEdited`, `MessageDeleted`
- [x] Mobil: `Message` modeli + `Reaction` modeli; `chat_repository` üzerinden REST çağrıları (`addReaction`, `removeReaction`, `edit`, `delete`)
- [x] Mobil: `chat_signalr_client` yeni hub event handler'ları
- [x] Mobil: `ChatController` — long-press → action sheet, optimistic edit/delete/react, incoming reaction/edit/delete dedup
- [x] Mobil: Yeni widget'lar — `composer_chip` (alıntılı yanıt başlığı), `message_actions_sheet` (long-press menüsü), `quoted_preview` (mesaj balonunda alıntı önizlemesi), `reaction_badges` (mesaj altında 👍 ❤️ ... rozetleri)
- [x] Mobil: `emoji_picker_flutter` paketi — reaction picker
- [ ] Cihazda manuel test — kullanıcı UX onayı bekleniyor
- [ ] `Pin` endpoint + UI — schema hazır, sonraki adım
- [ ] `TTL` (couple ayarından) — schema hazır, ayar ekranı + scheduled cleanup gerek
- [ ] `Ephemeral` ("anlık fotoğraf") — schema hazır, view-once medya akışıyla birlikte (Phase 4.5)

## Kararlar

- **Edit penceresi 15 dakika** → `MessageService.EditAsync`'te server-side enforce. WhatsApp standardına yakın; daha kısa tutmak (örn. 5 dk) yazım hatası düzeltme penceresini gereksiz daraltıyordu, daha uzun tutmak ise konuşmanın geriye dönük yeniden yazılmasına izin veriyor. 15 dk dengeli; gelecekte couple ayarı yapılabilir.
- **Sadece sender edit/delete-for-both yapabilir** → `EditAsync` ve `DeleteAsync(ForBoth)` `NotMessageSenderException` fırlatır. "for me" silme her iki taraf için açık (kendi tarafından gizlemek temel hak).
- **Delete two-mode**:
  - `ForMe` → `MessageDeletedForUser` tablosuna kayıt; mesaj diskte korunur, partner görmeye devam eder, listeleme sırasında çağıran user için filtrelenir.
  - `ForBoth` → `Messages.DeletedAt` + `DeletedByUserId` doldurulur; mesaj iki tarafça da "Bu mesaj silindi" placeholder olarak görünür (içerik korunur ama UI render etmez — mahkemelik / şikayet senaryolarında server-side hâlâ erişilebilir).
- **Reaction idempotency**: `(MessageId, UserId, Emoji)` unique. Aynı emoji ikinci kez `AddReactionAsync`'e gelirse mevcut kaydı sessizce döndürür (race-safe). Remove de yoksa 204 sessiz.
- **Reaction set'i serbest** → tek emoji listesine kilitlemedik; emoji_picker_flutter ile tüm Unicode emoji'leri seçilebilir. Çiftin "kendi dili" olan emoji'lere alan açmak için.
- **Reactions list'i mesajla birlikte** → `ListAsync` artık `MessageWithReactions` döner. Ayrı `GET /messages/{id}/reactions` endpoint'i yok; pagination çağrısı reaction'ları join'le getiriyor. N+1 sorununu engellemek için `_db.MessageReactions.Where(r => messageIds.Contains(r.MessageId))` tek sorguda toplanıyor.
- **Hub event'leri ayrı, payload küçük** → `MessageReacted(messageId, ReactionDto)` sadece reaction bilgisi taşır; istemci listeye merge eder. Mesaj objesini her seferinde yeniden broadcast etmek bant genişliğini boş yere harcar.
- **Pin/TTL/Ephemeral kolonları neden bu PR'da?** → Migration'ı bölmemek için. EF Core migration zincirini "her özelliğe bir migration" yapmak development sırasında schema'ları kararsızlaştırıyordu. Schema bütünüyle gelir, endpoint'ler kademeli açılır. Production'a çıkmadan önce konsolide migration yine yazılabilir.

## Eklenen / Değişen dosyalar

### Backend (yeni)
- `src/Couple.Domain/Entities/MessageReaction.cs`
- `src/Couple.Domain/Entities/MessageDeletedForUser.cs`
- `src/Couple.Infrastructure/Persistence/Migrations/20260510175838_AddRichMessages.cs` (+ Designer)

### Backend (değişen)
- `src/Couple.Domain/Entities/Message.cs` — yeni alanlar (yukarıda)
- `src/Couple.Domain/Abstractions/IMessageService.cs` — `MessageWithReactions`, `DeleteScope`, exception tipleri, yeni metotlar
- `src/Couple.Infrastructure/Messaging/MessageService.cs` — implementasyonlar
- `src/Couple.Infrastructure/Persistence/CoupleDbContext.cs` — `MessageReactions`, `MessageDeletedForUsers` DbSet + index'ler + couple-scope filter
- `src/Couple.Api/Endpoints/MessageEndpoints.cs` — PATCH/DELETE/reactions endpoint'leri
- `src/Couple.Api/Endpoints/MessageDto.cs` — `ReactionDto`, ek alanlar
- `src/Couple.Api/Hubs/ChatHub.cs` — `IChatClient` event'leri, `ReplyToMessageId` payload

### Mobile (yeni widget'lar)
- `lib/features/chat/presentation/widgets/composer_chip.dart`
- `lib/features/chat/presentation/widgets/message_actions_sheet.dart`
- `lib/features/chat/presentation/widgets/quoted_preview.dart`
- `lib/features/chat/presentation/widgets/reaction_badges.dart`

### Mobile (değişen)
- `lib/features/chat/data/message_models.dart` — `Reaction`, ek alanlar, `copyWith` genişletildi
- `lib/features/chat/data/chat_repository.dart` — `addReaction`/`removeReaction`/`edit`/`delete`
- `lib/features/chat/data/chat_signalr_client.dart` — yeni event stream'leri
- `lib/features/chat/state/chat_controller.dart` — optimistic update + incoming dedup
- `lib/features/chat/presentation/chat_screen.dart` — long-press, action sheet, alıntı önizleme, reaction badge, edited/deleted görünüm
- `pubspec.yaml`, `pubspec.lock` — `emoji_picker_flutter: ^4.4.0`

## Doğrulama

```bash
# Backend
cd backend && dotnet build       # 0 hata, 4 NU1903 uyarı (System.Security.Cryptography.Xml — transitive, bu PR ile ilgisiz)
# Mobile
cd mobile/couple_app && flutter analyze   # No issues found
```

- ✅ Backend build temiz
- ✅ Flutter analyze temiz
- ⚠️ NU1903 — `System.Security.Cryptography.Xml 9.0.0` advisory'si, transitive bağımlılık. Ayrı bir issue olarak ele alınmalı; bu fazın kapsamı dışı.
- ⏸ Cihazda manuel UX testi yapılmadı

### Kullanıcı doğrulaması gerekli (v2)

Baseline test senaryosunun üzerine ek olarak:

1. Bir mesaja **uzun bas** → action sheet açılmalı (Yanıtla / Düzenle / Sil / Reaksiyon)
2. **Yanıtla** → composer üstünde alıntı chip'i belirmeli; mesaj atınca kâğıt balonun üstünde alıntı önizlemesi görünmeli
3. **Reaksiyon** → emoji picker → seç → mesaj altında rozet; aynı emoji'ye ikinci kez basınca kalkmalı
4. **Düzenle (kendi mesajı)** → input dolar → değiştir → "düzenlendi" rozeti
5. **Düzenle (16 dk önce mesaj)** → 410 Gone / hata snackbar
6. **Sil → "Benim için"** → o cihazda gizlenir, partner cihazda durur
7. **Sil → "İkimiz için"** → iki cihazda da "Bu mesaj silindi" placeholder
8. Partner offline iken yapılan reaction/edit/delete → partner online olunca history yüklenince doğru görünmeli (dedup)

### Bilinen kısıtlar (bu fazda)

- Edit/delete için 15 dk dışı net hata mesajı UX'i: snackbar/dialog mı, yoksa input içinde mi? — UX testte netleşecek
- Reaction badge'lerinin yoğun konuşmada layout'u — uzun mesajlarda taşma olabilir, kullanıcı geri bildirimi alınacak
- "for me" silinmiş mesaj sayısı bir yerde gösterilmiyor — istenirse "X mesajı sen sakladın" indikator eklenebilir

---

## Açık sorular / sonraki faza taşınanlar

- [ ] Drift offline queue (3.1)
- [ ] FCM push (3.2 veya Phase 4 başı) — Firebase project, google-services.json gerekiyor
- [ ] Pin endpoint + UI (3.3) — schema hazır
- [ ] Mesaj TTL (3.4) — couple ayarı + scheduled cleanup; schema hazır
- [ ] Ephemeral / "anlık fotoğraf" (4.5) — view-once medya akışıyla; schema hazır
- [ ] ADR-0007 yazılmalı: edit window, delete scopes, reaction idempotency kararları
