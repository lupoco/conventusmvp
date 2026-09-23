#!/usr/bin/env bash
# sql/07_harden_functions.sql ONCE/SONRA kaniti.
# Gercek Supabase'in varsayilani taklit edilir: public'teki tum fonksiyonlar
# anon'a acik. Sonra 07 uygulanir ve anon'un hicbirini cagiramadigi,
# okumalarin/formun calismaya devam ettigi gosterilir.
set -euo pipefail
PGBIN=/usr/lib/postgresql/16/bin
PGDATA=${PGDATA_DIR:-/var/tmp/pgdata_cv_verify}
PORT=${PGPORT:-5434}; RUN=/var/tmp
PSQL="$PGBIN/psql -h $RUN -p $PORT -U postgres -d postgres"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! su postgres -c "$PSQL -Atc 'select 1'" >/dev/null 2>&1; then
  su postgres -c "$PGBIN/pg_ctl -D $PGDATA -o '-k $RUN -p $PORT -c listen_addresses=' -l $RUN/pg_fn.log start" >/dev/null
  sleep 2
fi
for f in sql/07_harden_functions.sql sql/07_harden_functions_ROLLBACK.sql; do
  cp "$ROOT/$f" "$RUN/$(basename "$f")"; chmod 644 "$RUN/$(basename "$f")"
done

cat > "$RUN/fnprobe.sql" <<'EOS'
\pset format unaligned
\pset fieldsep ' | '
select 'anon EXECUTE olan fonksiyon' as rapor, count(*) as adet
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and has_function_privilege('anon', p.oid, 'EXECUTE');
select 'authenticated EXECUTE olan fonksiyon' as rapor, count(*) as adet
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and has_function_privilege('authenticated', p.oid, 'EXECUTE');
set role anon;
select 'anon: connectus_directory()' as deneme,
  cvtest.probe('connectus_directory', 'select public.connectus_directory(5)') as sonuc;
select 'anon: convexus_import_pool_to_event()' as deneme,
  cvtest.probe('convexus_import_pool_to_event', 'select public.convexus_import_pool_to_event()') as sonuc;
select 'anon: conventity_pending_members()' as deneme,
  cvtest.probe('conventity_pending_members', 'select * from public.conventity_pending_members()') as sonuc;
select 'anon OKUMA: gm_providers_public' as deneme,
  cvtest.probe('gm_providers_public SELECT', 'select count(*) from public.gm_providers_public') as sonuc;
select 'anon OKUMA: conventus_managed_events' as deneme,
  cvtest.probe('conventus_managed_events SELECT', 'select count(*) from public.conventus_managed_events') as sonuc;
select 'anon FORM: access_requests INSERT' as deneme,
  cvtest.probe('conventity_access_requests INSERT',
    $q$insert into public.conventity_access_requests (full_name,email,purpose)
       values ('Fn Test','fn'||floor(random()*1e9)::text||'@example.com','deneme')$q$) as sonuc;
reset role;
EOS
chmod 644 "$RUN/fnprobe.sql"
run(){ su postgres -c "$PSQL -q -v ON_ERROR_STOP=1 -f $RUN/$1" 2>&1; }
clean(){ grep -v '^Output format\|^Field separator\|^SET$\|^RESET$\|^$'; }

echo "== 0) Supabase varsayilanini taklit et (tum fonksiyonlar anon'a acik) =="
run 07_harden_functions_ROLLBACK.sql >/dev/null && echo "   tamam"
echo
echo "########## ONCE ##########"
run fnprobe.sql | clean
echo
echo "== 1) 07 uygulaniyor =="
run 07_harden_functions.sql | clean
echo
echo "########## SONRA ##########"
run fnprobe.sql | clean
echo
echo "== 2) idempotans: 07 ikinci kez =="
run 07_harden_functions.sql >/dev/null && echo "   hatasiz"
