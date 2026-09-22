-- ============================================================================
-- conventity_problems — otorite metninden org üret + bağla  ·  C-fazı 2/2
-- 2026-07-23
--
-- originating_authority serbest metnindeki her farklı değeri 'institution'
-- tipi bir conventity_orgs kaydına dönüştürür ve problemi ona bağlar.
-- ÖNCE: *_authority_fk.sql çalışmış olmalı.
--
-- Idempotent: source_ref='authority:<slug>' + NOT EXISTS; yalnız BOŞ bağları
-- doldurur (elle bağlanmışa dokunmaz). Generic — hiçbir isim hardcode edilmez
-- (CLAUDE.md 'nötr tut' yasağına uygun). Geri alma: *_ROLLBACK.
--
-- NOT: hepsi 'institution' olarak açılır; ulus (nation) olanları admin Core'da
-- yeniden sınıflandırır. Serbest metin varyasyonları yakın-çift üretebilir —
-- birleştirme admin işidir (metin korunuyor, veri kaybı yok).
-- ============================================================================

-- 1) Farklı otorite metinlerinden institution org üret (idempotent) ----------
-- NOT: conventity_orgs.source bir CHECK kısıtına tabidir; 'import' kesin
-- geçerli (Orion importer de onu kullanır). Kimlik/geri-alma source_ref
-- ('authority:<slug>') üzerinden yürür — source değerinden bağımsız.
insert into public.conventity_orgs (legal_name, org_type, source, source_ref)
select distinct
       trim(p.originating_authority),
       'institution',
       'import',
       'authority:'||lower(regexp_replace(trim(p.originating_authority),'[^a-zA-Z0-9]+','_','g'))
from public.conventity_problems p
where nullif(trim(p.originating_authority),'') is not null
  and not exists (
    select 1 from public.conventity_orgs o
    where o.source_ref = 'authority:'||lower(regexp_replace(trim(p.originating_authority),'[^a-zA-Z0-9]+','_','g'))
  );

-- 2) Problemleri org'a bağla — yalnız henüz bağlı olmayanları -----------------
update public.conventity_problems p
set authority_org_id = o.id
from public.conventity_orgs o
where p.authority_org_id is null
  and nullif(trim(p.originating_authority),'') is not null
  and o.source_ref = 'authority:'||lower(regexp_replace(trim(p.originating_authority),'[^a-zA-Z0-9]+','_','g'));

notify pgrst, 'reload schema';

-- ============================================================================
-- DOĞRULAMA:
--   select count(*) from conventity_orgs where source='authority_seed';   -- yeni kurumlar
--   select count(*) from conventity_problems where authority_org_id is not null;  -- bağlı problemler
-- ============================================================================
