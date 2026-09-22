-- ============================================================
-- Conventity — Giriş kaydı (sign-in log)
-- 2026-07-21
--
-- AMAÇ: Siteye başarılı her girişi (parola + Google/LinkedIn OAuth)
-- görünür, sorgulanabilir bir kayda düşürmek. Supabase auth login
-- olaylarını istemciye açık bir tabloda tutmaz; bu tablo o boşluğu
-- doldurur. Core → "Girişler" sekmesi buradan okur.
--
-- ÇALIŞTIRMA: Supabase SQL Editor'de tek transaction olarak çalıştır.
-- Idempotent — tekrar çalıştırılabilir. Geri alma: *_ROLLBACK.sql
--
-- VARSAYIMLAR (canlı şemaya göre doğrula):
--   • conventity_is_admin(text) mevcut (Core'un ecosystem kapısı)
--   • gen_random_uuid() kullanılabilir (Supabase varsayılan)
--   • Giriş yapan kullanıcının auth.uid()'i vardır (authenticated)
-- ============================================================

-- 1) Append-only giriş kaydı tablosu ---------------------------
create table if not exists public.conventity_signin_log (
  id            uuid primary key default gen_random_uuid(),
  auth_user_id  uuid not null,
  email         text,
  method        text not null default 'password'
                  check (method in ('password','google','linkedin_oidc','other')),
  user_agent    text,
  at            timestamptz not null default now()
);

create index if not exists idx_conv_signin_at    on public.conventity_signin_log(at desc);
create index if not exists idx_conv_signin_user  on public.conventity_signin_log(auth_user_id);
create index if not exists idx_conv_signin_method on public.conventity_signin_log(method);

-- 2) RLS -------------------------------------------------------
alter table public.conventity_signin_log enable row level security;

-- Okuma: yalnız ekosistem yöneticisi (Core kapısı).
drop policy if exists conv_signin_select on public.conventity_signin_log;
create policy conv_signin_select
  on public.conventity_signin_log
  for select
  using (conventity_is_admin('ecosystem'));

-- Yazma: giriş yapan kullanıcı YALNIZ kendi satırını ekleyebilir.
-- (auth_user_id, oturumun sahibiyle eşleşmek zorunda — başkası adına
--  kayıt üretilemez. İstemci logger bu satırı yazar.)
drop policy if exists conv_signin_insert_self on public.conventity_signin_log;
create policy conv_signin_insert_self
  on public.conventity_signin_log
  for insert
  with check (auth.uid() = auth_user_id);

-- Bilerek YOK: update/delete politikası → tablo append-only'dir.

-- 3) PostgREST şema önbelleğini tazele --------------------------
notify pgrst, 'reload schema';

-- ============================================================
-- DOĞRULAMA (çalıştırdıktan sonra):
--   • Siteye giriş yap → conventity_signin_log'a 1 satır düşmeli.
--   • Admin olmayan hesap 0 satır görmeli (select RLS).
--   • Kimse satır update/delete edememeli (politika yok).
--   select method, email, at from conventity_signin_log order by at desc limit 5;
-- ============================================================
