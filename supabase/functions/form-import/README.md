# form-import

PDF/Word kayıt formunu dijital form tanımına çeviren Edge Function.

## Ne yapar

1. Tarayıcı dosyayı **kendisi** düz metne çevirir (`pdf.js` / `JSZip`).
   Buraya yalnızca metin gelir — ikili dosya yüklenmez, hiçbir yerde saklanmaz.
2. Fonksiyon, çağıranın o etkinliği yönetebildiğini `conventity_can_manage_event`
   ile doğrular. Aksi halde **403**.
3. Metni modele verir ve **tool use** ile katı bir şemaya zorlar.
4. Dönen öneriyi **sunucuda** yeniden doğrular: anahtar biçimi, tip beyaz
   listesi, çekirdek anahtar beyaz listesi, alan sayısı sınırı, tekrar eden
   anahtar. Model şemanın dışına çıkamaz.
5. Öneriyi `conventus_form_imports`'a yazar ve istemciye **döndürür**.

## Ne YAPMAZ

`registration_field_defs`'i **yazmaz**. Öneriyi döner; yönetici ekranda görür,
düzeltir, seçtiklerini kendisi uygular. *AI önerir, insan karar verir.*

## Ortam değişkenleri

| Değişken | Kaynak |
|---|---|
| `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` | Supabase otomatik sağlar |
| `ANTHROPIC_API_KEY` | **elle** eklenir — `supabase secrets set` |
| `FORM_IMPORT_MODEL` | isteğe bağlı, varsayılan `claude-sonnet-5` |

## Kurulum

```bash
# 1) SQL (denetim tablosu)
#    sql/19_form_import.sql  -> Supabase SQL Editor

# 2) API anahtarı
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...

# 3) Deploy
supabase functions deploy form-import
```

Fonksiyon yayında değilken arayüz **404** alır ve "bu özellik henüz açılmadı"
uyarısını gösterir — sessizce bozulmaz.

## Sınırlar

- Metin `60 000` karakterde kesilir; kesilirse `notes`'ta söylenir.
- En fazla `60` alan, `20` onay metni kabul edilir.
- **Taranmış (görüntü) PDF çalışmaz** — metin katmanı yoktur. Arayüz bunu
  ayrıca söyler. OCR bu sürümde yok.
