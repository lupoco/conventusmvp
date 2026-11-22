# org-invite — Edge Function

conventity.org üyeliği için adres tanımlar. `/yonetim/` → **Üyeler** sekmesi çağırır.

- Çağıranın ekosistem yöneticisi olduğunu `conventity_is_admin('ecosystem')` ile doğrular; değilse `403`.
- Adresle hesap yoksa parolasız bir hesap açar; `conventity_org_members` tablosuna `invited` satırı ekler.
- **Kişiye e-posta göndermez.** Kişi, conventity.org üyelik sayfasında adresini yazdığında kod gider.
- Yalnız `https://conventity.com` kökeninden çağrılabilir (CORS).

Neden gerekli: üyelik sayfası tanımlı olmayan adrese kod göndermemeli ve hesap açmamalıdır; bu yüzden
sayfa yeni hesap açmaz, hesabı bu işlev açar. İşlev dağıtılmamışsa yönetim uygulaması bunu söyler ve
tanımlanan kişi giriş yapamaz.

Silme bu işlevde değildir: `conventity_org_admin_remove` (sql/22) satırı ve, başka izi yoksa, hesabı siler.

## Deploy

```bash
supabase functions deploy org-invite
```

`verify_jwt` açık kalır. `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` otomatik gelir.
