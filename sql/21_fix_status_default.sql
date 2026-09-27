-- 21_fix_status_default.sql
-- HATA: conventus_registrations.status varsayilani 'pending' — ama 'pending'
-- CHECK listesinde YOK.
--
--   default : 'pending'
--   CHECK   : invited, draft, submitted, under_review, approved, rejected,
--             waitlisted, checked_in, cancelled, no_show
--
-- SONUCLARI
--   1) status BELIRTMEDEN yapilan her insert CHECK'e takilir. Kayit sihirbazi
--      status'u hep acikca yazdigi icin fark edilmemis; ama vekaleten kayit,
--      icesi aktarim veya yeni bir istemci yolu bunu ilk denemede yer.
--   2) Eger bir sekilde 'pending' satir olusursa (kisit eklenmeden once yazilmis
--      eski kayit gibi), o satirda BASKA bir kolonu guncellemek de patlar —
--      CHECK guncellemede tekrar degerlendirilir. Organizator o kaydi bir daha
--      duzenleyemez.
--
-- COZUM: varsayilan gecerli ve anlamli bir degere cekilir: 'submitted'.
-- CHECK'e 'pending' EKLENMEZ — ayni durumun dorduncu es anlamlisini
-- mesrulastirmak isi kotulestirirdi. (event-manage'deki "bekleyen" filtresi
-- zaten 'pending'i submitted ile birlikte sayiyor; okuma tarafi korunuyor.)
--
-- Mevcut satirlara DOKUNULMAZ. Yalnizca varsayilan degisir.
-- Idempotent.

begin;

alter table public.conventus_registrations
  alter column status set default 'submitted';

commit;

-- ---------------------------------------------------------------------------
-- DOGRULAMA
-- ---------------------------------------------------------------------------
select
  (select column_default from information_schema.columns
    where table_name='conventus_registrations' and column_name='status')  as "varsayilan ('submitted')",
  (select count(*) from public.conventus_registrations
    where status = 'pending')                                             as "eski pending satir (0 bekleniyor)";

-- Eski 'pending' satir CIKARSA: asagidakini elle calistirin. Durum anlamca
-- 'submitted' ile ayni; boylece o kayitlar tekrar duzenlenebilir olur.
--
--   update public.conventus_registrations set status='submitted' where status='pending';
