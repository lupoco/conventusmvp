-- ============================================================
-- Conventus — Sağlayıcı akreditasyonu → ekosistem "vendor" rolü (S44)
-- 2026-08-04
--
-- SORUN: gm-provider.html başvurusu gm_providers'a yazıyor ama sağlayıcıya
--   conventity_roles'ta 'vendor' rolü VERİLMİYOR. Sonuç: S43 post-login
--   yönlendirmesi (CV.homeFor('vendor') -> gm-provider.html) gerçek sağlayıcı
--   için hiç tetiklenmiyor ve sağlayıcı ekosistemde birinci-sınıf arz aktörü
--   değil (rol konsolu, RLS, matching onu 'vendor' görmüyor).
--
-- ÇÖZÜM: gm_providers.accredited true OLDUĞUNDA conventity_roles'a
--   (scope='conventus', role='vendor', status='active', auth_user_id=owner)
--   satırı ekleyen SECURITY DEFINER trigger. Akreditasyon geri alınırsa
--   yalnız OTOMATİK verilen rol 'revoked' olur (elle verilmiş vendor rolüne
--   DOKUNULMAZ). Mevcut akredite firmalar için tek seferlik backfill.
--
-- ÇALIŞTIRMA: Supabase SQL Editor, tek transaction. Idempotent. *_ROLLBACK.sql var.
-- ÖNCE: sql/00_introspect_v2.sql çalıştırıp conventity_roles kolonlarını doğrula
--       (auth_user_id · scope · scope_id · role · status · granted_via · note).
-- VARSAYIM: conventity_roles tek yetki kaynağı (conventus_community_v2.sql uygulanmış).
--   scope='conventus' için scope_id NULL olmalı (conventity_roles_scopeid_check).
-- NOT: conventity_roles'ta trg_role_audit var — bu insert/update audit'e düşer (istenen).
--   trg_membership_cascade scope<>'community' için erken return eder (etkilenmez).
-- POLİTİKALARA DOKUNULMAZ (22 canlı politika). Yeni RLS eklenmez.
-- ============================================================

-- 1) Rol verme/geri alma fonksiyonu -----------------------------------------
create or replace function public.conventus_provider_role_sync()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- (A) Akreditasyon KAZANILDI (INSERT accredited=true, ya da false/null -> true)
  if new.accredited is true
     and (tg_op = 'INSERT' or old.accredited is distinct from true)
     and new.owner_user_id is not null then
    -- varsa (revoked dahil) yeniden aktifleştir; yoksa ekle (NOT EXISTS yerine
    -- UPDATE + if not found — scope_id NULL olduğu için unique index dedupe etmez).
    update conventity_roles
       set status = 'active'
     where auth_user_id = new.owner_user_id
       and scope = 'conventus' and scope_id is null and role = 'vendor';
    if not found then
      insert into conventity_roles
        (auth_user_id, scope, scope_id, role, status, granted_via, note)
      values
        (new.owner_user_id, 'conventus', null, 'vendor', 'active', new.id,
         'auto: accredited Go&Meet provider');
    end if;

  -- (B) Akreditasyon GERİ ALINDI (true -> false/null): yalnız OTOMATİK rolü revoke et
  elsif tg_op = 'UPDATE'
     and old.accredited is true and new.accredited is not true
     and new.owner_user_id is not null then
    update conventity_roles
       set status = 'revoked'
     where auth_user_id = new.owner_user_id
       and scope = 'conventus' and scope_id is null and role = 'vendor'
       and note like 'auto:%';   -- elle verilmiş vendor rolüne dokunma
  end if;

  return new;
end $$;

-- 2) Trigger (yalnız accredited kolonu değişiminde / insert'te) --------------
drop trigger if exists trg_provider_role_sync on public.gm_providers;
create trigger trg_provider_role_sync
  after insert or update of accredited on public.gm_providers
  for each row execute function public.conventus_provider_role_sync();

-- 3) BACKFILL — mevcut akredite firmalar (NOT EXISTS guard'lı, tek sefer) -----
insert into conventity_roles
  (auth_user_id, scope, scope_id, role, status, granted_via, note)
select p.owner_user_id, 'conventus', null, 'vendor', 'active', p.id,
       'auto: accredited Go&Meet provider (backfill)'
from gm_providers p
where p.accredited is true
  and p.owner_user_id is not null
  and not exists (
    select 1 from conventity_roles r
     where r.auth_user_id = p.owner_user_id
       and r.scope = 'conventus' and r.scope_id is null and r.role = 'vendor'
  );

-- 4) DOĞRULAMA (çalıştırıp gözle kontrol et) --------------------------------
-- select count(*) filter (where accredited) as akredite_firma from gm_providers;
-- select count(*) as vendor_rolu from conventity_roles
--   where scope='conventus' and role='vendor' and note like 'auto:%';
-- Bu iki sayı (owner_user_id dolu olanlar için) eşleşmeli.
