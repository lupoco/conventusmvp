-- ============================================================
-- Conventity — Üyelik kapısı (members-only login)  ·  geçici
-- 2026-07-22
--
-- AMAÇ: Canlıda ŞU AN için yalnız "üye" olanlar giriş yapabilsin.
--   • Giriş (signInWithPassword / OAuth) zaten auth hesabı gerektiriyor.
--   • Ama register.html açık self-servis kayıt yapıyor (auth.users + metadata).
--   • Bu RPC, oturum açan kullanıcının GERÇEKTEN provizyonlanmış bir üye olup
--     olmadığını söyler. Arayüz (login.html / index.html) bunu çağırır;
--     üye değilse signOut eder.
--
-- ÇALIŞTIRMA: Supabase SQL Editor'de tek transaction. Idempotent.
--   Geri alma: 2026-07-22_conventity_members_only_ROLLBACK.sql
--   ÖNEMLİ — bu SQL'i arayüz değişikliğinden ÖNCE uygula; yoksa RPC
--   bulunamaz ve fail-closed arayüz herkesi (adminler dahil) kilitler.
--
-- VARSAYIMLAR (canlı şemaya göre doğrula):
--   • public.conventity_is_admin(text) mevcut (ecosystem kapısı)
--   • public.conventity_people(auth_user_id uuid, email text) mevcut
--   • public.conventity_roles(auth_user_id uuid) mevcut
--   • auth.uid() / auth.jwt() Supabase'te kullanılabilir
-- ============================================================

-- "Üye" tanımı: aşağıdakilerden biri doğruysa üyedir —
--   (a) ecosystem admin (adminler her zaman üye),
--   (b) conventity_roles'ta auth_user_id eşleşen bir rol satırı var,
--   (c) conventity_people'da auth_user_id eşleşen bir kimlik var,
--   (d) conventity_people'da JWT e-postasıyla eşleşen bir kimlik var
--       (henüz auth_user_id bağlanmamış ama e-postası provizyonlanmış üye).
-- Self-servis kayıt (yalnız auth.users + metadata role:'member') hiçbirini
-- karşılamaz → üye DEĞİL, ta ki admin core.html'de kişi/rol açana kadar.
create or replace function public.conventity_is_member()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce(public.conventity_is_admin('ecosystem'), false)
    or exists (
      select 1 from public.conventity_roles r
      where r.auth_user_id = auth.uid()
    )
    or exists (
      select 1 from public.conventity_people p
      where p.auth_user_id = auth.uid()
    )
    or (
      nullif(auth.jwt() ->> 'email', '') is not null
      and exists (
        select 1 from public.conventity_people p
        where p.email is not null
          and lower(p.email) = lower(auth.jwt() ->> 'email')
      )
    );
$$;

-- Oturum açmış kullanıcılar çağırabilsin (fonksiyon kendi içinde auth.uid()
-- kullanır; başkasının üyeliğini sorgulayamaz). anon da çağırabilir ama
-- oturum yoksa auth.uid() null → false döner.
grant execute on function public.conventity_is_member() to authenticated, anon;

-- PostgREST yeni fonksiyonu görsün (yoksa rpc('conventity_is_member') 404).
notify pgrst, 'reload schema';
