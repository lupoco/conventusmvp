#!/usr/bin/env bash
# Butun test takimini tek komutta kosar.
#   scripts/test-all.sh
# Gerekli: yerel PostgreSQL (verify-clean-install.sh ile kurulmus),
#          node + playwright (global), bos 8099 portu.
# Cikis kodu 0 = hepsi yesil.
set -uo pipefail
cd "$(dirname "$0")/.."
PGBIN=/usr/lib/postgresql/16/bin
PORT=${PGPORT:-5434}; RUN=/var/tmp
PSQL="$PGBIN/psql -h $RUN -p $PORT -U postgres -d postgres"
FAIL=0

say(){ printf '\n\033[1m== %s\033[0m\n' "$*"; }
ok(){  printf '  ✅ %s\n' "$*"; }
no(){  printf '  ❌ %s\n' "$*"; FAIL=1; }

say "yerel PostgreSQL"
if ! su postgres -c "$PSQL -Atc 'select 1'" >/dev/null 2>&1; then
  su postgres -c "$PGBIN/pg_ctl -D ${PGDATA_DIR:-/var/tmp/pgdata_cv_verify} \
    -o '-k $RUN -p $PORT -c listen_addresses=' -l $RUN/pg_all.log start" >/dev/null 2>&1
  sleep 3
fi
su postgres -c "$PSQL -Atc 'select 1'" >/dev/null 2>&1 && ok "ayakta" || { no "baslatilamadi"; exit 1; }

say "kanonik duruma getir"
# Testler onceki kosunun biraktigi duruma bagimli olmamali. Yetki tanimlayan
# migration'lar idempotent; her kosunun basinda kurulum sirasini tekrar
# uyguluyoruz. (Ilk surumde bu yoktu: harden-grants'in ROLLBACK'i anon'a
# SELECT birakiyordu ve BIR SONRAKI kosuda registration-wizard testi
# "anon onaylari okudu" diye patliyordu.)
for f in sql/04_access_requests.sql sql/06_pending_members.sql \
         sql/09_registration_wizard.sql sql/10_protocol_reference.sql \
         sql/11_protocol_seed.sql sql/12_protocol_ui.sql sql/13_protocol_optional.sql sql/05_harden_grants.sql \
         sql/07_harden_functions.sql; do
  cp "$f" "$RUN/_m.sql"; chmod 644 "$RUN/_m.sql"
  out=$(su postgres -c "$PSQL -q -v ON_ERROR_STOP=1 -f $RUN/_m.sql" 2>&1)
  if echo "$out" | grep -qiE "ERROR:"; then no "$(basename "$f")"; echo "$out" | grep -i "ERROR:" | head -2 | sed 's/^/       /'
  else ok "$(basename "$f")"; fi
done

say "SQL testleri"
for f in scripts/test-access-requests.sql scripts/test-pending-members.sql \
         scripts/test-registration-wizard.sql scripts/test-protocol-reference.sql \
         scripts/smoke-landcom-conference.sql \
         scripts/smoke-mvp-loop.sql; do
  cp "$f" "$RUN/_t.sql"; chmod 644 "$RUN/_t.sql"
  out=$(su postgres -c "$PSQL -f $RUN/_t.sql" 2>&1)
  if echo "$out" | grep -qiE "GUVENLIK HATASI|ERROR:|^HATA:"; then
    no "$(basename "$f")"; echo "$out" | grep -iE "GUVENLIK HATASI|ERROR:|HATA:" | head -3 | sed 's/^/       /'
  else ok "$(basename "$f")"; fi
done

say "yetki sertlestirme (once/sonra)"
for f in scripts/test-harden-grants.sh scripts/test-harden-functions.sh; do
  out=$(bash "$f" 2>&1)
  if echo "$out" | grep -qiE "^HATA|ERROR:"; then no "$(basename "$f")"; else ok "$(basename "$f")"; fi
done

say "anon okuma regresyonu"
cp scripts/test-anon-read-regression.sql "$RUN/_r.sql"; chmod 644 "$RUN/_r.sql"
out=$(su postgres -c "$PSQL -c 'set role anon' -f $RUN/_r.sql" 2>&1)
echo "$out" | grep -q "0 HATA" && ok "$(echo "$out" | grep -o 'anon okuma:.*')" || no "anon okumalarinda hata"

say "politika fonksiyonlari anon'a acik mi"
# 07 beyaz listeyi pg_policies'ten turetir; SONRADAN eklenen bir politika yeni
# bir fonksiyon cagiriyorsa liste eskir ve anon'un okumalari patlar.
miss=$(su postgres -c "$PSQL -Atc \"
 select coalesce(string_agg(nm,', '),'') from (
  select distinct p.proname nm from pg_policies pol,
   lateral regexp_matches(coalesce(pol.qual,'')||' '||coalesce(pol.with_check,''),'([a-z_][a-z0-9_]*)\\(','g') m
  join pg_proc p on p.proname=m[1]
  join pg_namespace n on n.oid=p.pronamespace and n.nspname='public'
  where pol.schemaname='public' and not has_function_privilege('anon',p.oid,'EXECUTE')) x\"" 2>&1)
[ -z "$miss" ] && ok "eksik yok" || no "anon EXECUTE'u eksik: $miss  → 07_harden_functions.sql'i tekrar calistir"

say "sayfa ↔ sema"
out=$(python3 scripts/check-page-schema-refs.py --psql "$PSQL" 2>&1)
echo "$out" | grep -q "✓" && ok "$(echo "$out" | grep '✓')" || { no "eksik referans"; echo "$out" | tail -5 | sed 's/^/       /'; }

say "JS sozdizimi + butunluk"
for f in core.html under-construction.html index.html assets/i18n.js assets/cv-core.js \
         platforms/conventus/register-conventus.html platforms/conventus/event-manage.html; do
  if [[ "$f" == *.html ]]; then
    python3 -c "
import re,sys
h=open('$f',encoding='utf-8').read()
open('/tmp/_s.js','w',encoding='utf-8').write('\n'.join(re.findall(r'<script>(.*?)</script>',h,re.S)))
b=h.count('<body')
sys.exit(0 if b==1 else 3)"
    rc=$?
    [ $rc -eq 3 ] && { no "$f — <body> sayisi 1 degil (cift icerik?)"; continue; }
    node --check /tmp/_s.js >/dev/null 2>&1 && ok "$f" || no "$f — JS sozdizimi"
  else
    node --check "$f" >/dev/null 2>&1 && ok "$f" || no "$f — JS sozdizimi"
  fi
done

say "tarayici testleri"
if ! curl -s -o /dev/null http://localhost:8099/index.html; then
  (npx --yes http-server -p 8099 -s . >/dev/null 2>&1 &) ; sleep 3
fi
for t in scripts/test-register-wizard.mjs scripts/test-register-ref-degraded.mjs \
         scripts/test-register-proto-off.mjs \
         scripts/test-event-form-tab.mjs scripts/test-event-protocol-tab.mjs \
         scripts/test-go-and-meet.mjs \
         scripts/test-core-pending-panel.mjs scripts/test-core-access-panel.mjs \
         scripts/test-access-form.mjs; do
  out=$(node "$t" 2>&1)
  if [ $? -eq 0 ] && ! echo "$out" | grep -qiE "✗|HATA:"; then ok "$(basename "$t")"
  else no "$(basename "$t")"; echo "$out" | tail -4 | sed 's/^/       /'; fi
done

printf '\n'
[ $FAIL -eq 0 ] && printf '\033[1m== HEPSI YESIL\033[0m\n' || printf '\033[1m== BASARISIZ ADIM VAR\033[0m\n'
exit $FAIL
