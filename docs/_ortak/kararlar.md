# Karar Kaydı

Kararlar tarihle ve tek satırla yazılır. Yapay zekâ çıktısı öneridir; buraya
yalnız insan onayıyla verilmiş kararlar girer.

## Verilen kararlar

| Tarih | Karar |
|---|---|
| 2026-11-17 | Ajan ofisi bu depoda `.claude/agents/` altında kurulur; ana oturum Genel Müdür'dür. İlk kadro: merkez, Conventus ve Consultus (14 ajan). Bu satır, kurulum PR'ı onaylandığında geçerlidir. |
| 2026-11-18 | Açık Fırsat Bülteni `conventity.org` adresinde, yalnız bültene ait ayrı bir depoda (`lupoco/conventity-bulten`) ve kendi ofisiyle yayımlanır. Eski deneme sitesi bir alt alan adına taşınır. (K-02 kapandı; K-01'in yayın yeri bölümü kapandı.) |

## Açık kararlar

| # | Konu | Seçenekler | Öneri |
|---|---|---|---|
| K-01 | Bülten abone listesi hangi projede durur ve e-postayı hangi hizmet gönderir? | (a) Liste canlı projede (`conventity-prod`), altyapıyı Consultus ofisi kurar. (b) Ayrı bir bülten hizmeti. | (a). Abone listesi gerçek kişi verisidir; tek yerde ve yetki kurallarıyla durmalı. Gönderim hizmeti ayrıca seçilir. |
| K-03 | Kartvizitten kişi ekleme ve topluluk oluşturma hangi modüle aittir ve hangi kartlar girilebilir? | (a) Consultus bülten aboneliğinin yönetici aracı. (b) Connectus üyelik akışı. | (a), şu koşulla: yalnız kişinin Conventity için açıkça verdiği kart girilir; bülten için ayrıca açık rıza alınır. |
| K-04 | Tasarım kimliği: depodaki v6 token'ları, yeni kimlik kararı ve "Yakında" ekranındaki tema birbirinden farklı. Hangisi esas? | Üçünden biri seçilir; `assets/tokens.css` tek kaynak olur. | Kurucu seçer; frontend ajanları seçilen kimliğe göre birleştirir. |
