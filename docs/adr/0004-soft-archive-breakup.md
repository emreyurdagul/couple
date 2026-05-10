# ADR-0004: İlişki bittiğinde soft-archive

**Status:** Accepted
**Tarih:** 2026-05-10

## Context

Çiftler ayrılabilir, sonra barışabilir. Veriyi:
- (a) hemen silmek → barışmada eski anılar yok olur, geri dönüş yok;
- (b) export + sil → karmaşık akış, kullanıcı kararsızsa kararsız UX;
- (c) saklamak ama gizlemek → güvenli ama "veri hâlâ orada" gerçeği.

Kullanıcı (c)'yi seçti.

## Decision

`Couples.Status` enum: `Pending | Active | Ended`.

- `DELETE /couples/me` → `Status=Ended`, `EndedAt` set; **veri silinmez**.
- Couple-scoped global query filter, `CoupleId` eşleşmesinin yanı sıra ilişkili `Couple.Status == Active` kontrolünü de içerir → her iki kullanıcı için chat/konum/takvim **görünmez** olur.
- Aynı iki kullanıcı yeniden eşleşirse **yeni** `Couple` kaydı açılır (yeni `CoupleId`); eski `CoupleId` tarihte donmuş kalır. Mesajlar, konum geçmişi, takvim girdileri eski couple'a ait olarak DB'de durur ama hiçbir tarafa görünmez.
- Veri retention kararı (örn. 1 yıl sonra Ended couple'ları arşive almak / silmek) v2'ye bırakıldı.

## Consequences

- ➕ Barışmada "yeni başlangıç" hissi: yeni `CoupleId` ile temiz sayfa.
- ➕ GDPR talepleri için silme hâlâ mümkün (manuel admin endpoint).
- ➕ Yargı / ailevi durumlar (örn. boşanma kanıtı talebi) için veri kaybolmamış olur.
- ➖ DB büyür; retention politikası eklemeden uzun vadede temizlik yok.
- ➖ "Veri yok edildi" garantisi yok; gizlilik politikasında açıkça yazılmalı.
- 🔁 Hard delete'e geçiş: `Status=Ended` olan couple'ların child satırlarını silen migration job + politika güncellemesi.

## Alternatives considered

- **Hard delete**: en yüksek privacy ama "geri al" yok.
- **Export-then-delete**: mailto/zip akışı; çift güvenli ama operasyonel ek iş + her iki taraf onayı senkronizasyonu zor.
