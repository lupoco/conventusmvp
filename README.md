# conventusmvp — conventity.com

`conventity.com` için **temiz kurulum**: yeni repo, yeni (boş) Supabase projesi,
Conventus MVP döngüsü.

`conventity.org` (`lupoco/conventityme` + mevcut Supabase) **çalışma alanı olarak
kalır ve bu repodan hiç etkilenmez.** İki taraf arasında kod tek yönde akar
(.org → .com kopya), veri hiç akmaz.

## Durum

| Adım | Durum |
|---|---|
| §1 Repo + frontend kopyası, yarım sayfalar nav dışı | ✅ |
| §2 Config seam (`/assets/js/cv-config.js`) | ✅ — **değerler yer tutucu** |
| §3 Temiz Supabase + SQL sırası | ⏸ Supabase `ref` + anon key bekleniyor |
| §4 İlk admin (bootstrap owner) | ⏸ |
| §6 Hostinger → conventity.com deploy | ⏸ |

Ayrıntı: [`BOOTSTRAP.md`](BOOTSTRAP.md).

## Local dev

```bash
git clone https://github.com/lupoco/conventusmvp.git
cd conventusmvp
python3 -m http.server 8000
# → http://localhost:8000/register-conventus.html
```

`file://` ile açma — root-absolute `/assets` yolları, auth ve modüller kırılır.
Her zaman kökten HTTP sunucu.

## Ortam yapılandırması

Supabase URL + publishable anon key **tek dosyada**: `/assets/js/cv-config.js`.
Hiçbir sayfa bu iki değeri kendi içine gömmez. Doldurulmadığı sürece her sayfa
kırmızı bir uyarı şeridi gösterir.

Lisans/telif: Conventity.
