-- ════════════════════════════════════════════════════════════════════════
-- conventus_rls_hardening_s17_s18.sql
-- Faz A2 — RLS sertleştirme (canlı sistem; RLS = gerçek sınır)
--
--   S17  Duyuru audience görünürlüğü (T14)
--        Sorun: ann_public_read_published, audience'ı yok sayarak is_published
--        olan HER duyuruyu anon dahil herkese açıyor. 'organizers'/'approved'
--        hedefli duyurular sızıyor.
--        Çözüm: audience-farkında okuma politikası + yöneticiye tam okuma.
--
--   S18  Kayıt penceresi (T10)
--        Sorun: "reg: own insert" WITH CHECK sadece auth.uid()=user_id;
--        kayıt KAPALIYKEN bile katılımcı kendini kaydedebiliyor.
--        Çözüm: self-insert'i registration_open=true kapısına bağla.
--        (reg_manager_insert delegation'a DOKUNULMAZ — yönetici her zaman ekler.)
--
-- İdempotent: her create'ten önce drop if exists. Politika gövdeleri yalnızca
-- introspection'da doğrulanmış kolon/fonksiyonları kullanır.
-- Rollback bloğu en altta (yorumlu).
-- ════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────
-- S17 — conventus_announcements: audience-farkında okuma
-- ─────────────────────────────────────────────────────────────────────────

-- Geniş "yayınlanmış = herkese açık" politikasını kaldır (audience'ı yok sayıyordu).
drop policy if exists ann_public_read_published on conventus_announcements;

-- Yerine: yayınlanmış duyuru, audience'a göre görünür.
--   all               → herkes (anon dahil) — kamuya açık program
--   approved          → o etkinliğin onaylı/check-in katılımcıları
--   pending           → o etkinliğe başvurmuş (herhangi statü) kullanıcılar
--   community_members → etkinliğin topluluğunun aktif üyeleri
--   organizers        → etkinliği yönetebilenler (event_manager/organizer/admin)
-- Not: ann_owner_read (creator) ayrı politika olarak durmaya devam eder;
-- sahibi audience'tan bağımsız her şeyi görür.
create policy ann_audience_read on conventus_announcements
  for select to anon, authenticated
  using (
    is_published = true
    and (
      audience = 'all'
      or (
        audience = 'approved'
        and exists (
          select 1 from conventus_registrations r
          where r.event_id = conventus_announcements.event_id
            and r.user_id = auth.uid()
            and r.status in ('approved','checked_in')
        )
      )
      or (
        audience = 'pending'
        and exists (
          select 1 from conventus_registrations r
          where r.event_id = conventus_announcements.event_id
            and r.user_id = auth.uid()
        )
      )
      or (
        audience = 'community_members'
        and exists (
          select 1 from conventus_managed_events e
          where e.id = conventus_announcements.event_id
            and e.community_id is not null
            and conventity_in_community(e.community_id)
        )
      )
      or (
        audience = 'organizers'
        and exists (
          select 1 from conventus_managed_events e
          where e.id = conventus_announcements.event_id
            and conventity_can_manage_event(e.activity_id)
        )
      )
    )
  );

-- Yönetici (creator olmasa da) etkinliğin TÜM duyurularını okuyabilsin —
-- yönetim yüzeyi (announcements.html / event-manage) için. Additive, çakışmaz.
drop policy if exists ann_manager_read on conventus_announcements;
create policy ann_manager_read on conventus_announcements
  for select to authenticated
  using (
    exists (
      select 1 from conventus_managed_events e
      where e.id = conventus_announcements.event_id
        and conventity_can_manage_event(e.activity_id)
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- S18 — conventus_registrations: kayıt penceresi (self-insert)
-- ─────────────────────────────────────────────────────────────────────────

-- Kapısız self-insert'i kaldır.
drop policy if exists "reg: own insert" on conventus_registrations;

-- Yerine: kullanıcı yalnızca kendi kaydını VE etkinlik kayda açıkken ekleyebilir.
-- Yönetici on-behalf insert'i (reg_manager_insert) bundan etkilenmez.
create policy reg_self_insert_open on conventus_registrations
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from conventus_managed_events e
      where e.id = conventus_registrations.event_id
        and e.registration_open = true
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- Doğrulama
-- ─────────────────────────────────────────────────────────────────────────
select tablename, policyname, cmd
from pg_policies
where schemaname='public'
  and tablename in ('conventus_announcements','conventus_registrations')
  and policyname in ('ann_audience_read','ann_manager_read','reg_self_insert_open',
                     'ann_public_read_published','reg: own insert')
order by tablename, policyname;
-- Beklenen: ann_audience_read + ann_manager_read + reg_self_insert_open VAR;
--           ann_public_read_published + "reg: own insert" YOK.

-- ════════════════════════════════════════════════════════════════════════
-- ROLLBACK (gerekirse tek blok halinde çalıştır):
-- ════════════════════════════════════════════════════════════════════════
-- drop policy if exists ann_audience_read on conventus_announcements;
-- drop policy if exists ann_manager_read on conventus_announcements;
-- create policy ann_public_read_published on conventus_announcements
--   for select to anon, authenticated using (is_published = true);
--
-- drop policy if exists reg_self_insert_open on conventus_registrations;
-- create policy "reg: own insert" on conventus_registrations
--   for insert to authenticated with check (auth.uid() = user_id);
