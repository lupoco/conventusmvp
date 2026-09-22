# admin-users — Edge Function

Ekosistem yöneticisinin `auth.users` üzerinde güvenli işlem yapmasını sağlar
(`service_role` yalnız sunucuda). Core → **Kullanıcılar** sekmesindeki aksiyon
butonları bu fonksiyonu çağırır.

## Güvenlik modeli

- Çağıran, kendi oturum token'ını `Authorization: Bearer <access_token>` ile yollar.
- Fonksiyon `conventity_is_admin('ecosystem')`'i **çağıranın token'ıyla** doğrular.
  Admin değilse `403`.
- Yalnız doğrulandıktan sonra `service_role` ile işlem yapılır.
- Kendi kendini silme/yasaklama engellidir.
- Her başarılı işlem `conventity_audit`'e (`table_name='auth.users'`) düşer.

## İşlemler

`POST` body `{ "action": "...", "email": "hedef@site.com" }`

| action | etki |
|---|---|
| `reset`   | Hedefe parola sıfırlama e-postası gönderir (redirect: `/reset-password.html`) |
| `disable` | Kullanıcıyı yasaklar (~100 yıl) |
| `enable`  | Yasağı kaldırır |
| `delete`  | Kullanıcıyı siler (geri alınamaz) |

## Deploy

Supabase CLI ile (proje kökünden):

```bash
supabase functions deploy admin-users
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` ortam
değişkenleri Supabase tarafından otomatik enjekte edilir — elle secret
eklemeye gerek yok.

CLI yoksa: Dashboard → **Edge Functions → Create a function** → adını
`admin-users` yap, `index.ts` içeriğini yapıştır, **Deploy**.

## Test

```bash
curl -i -X POST 'https://shbwylrwpioqypbdhjgn.supabase.co/functions/v1/admin-users' \
  -H "Authorization: Bearer <ADMIN_ACCESS_TOKEN>" \
  -H 'Content-Type: application/json' \
  -d '{"action":"reset","email":"birisi@site.com"}'
```

Admin olmayan bir token `403 {"error":"not_admin"}` almalı.
