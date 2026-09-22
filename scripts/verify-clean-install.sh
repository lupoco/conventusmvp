#!/usr/bin/env bash
# Temiz kurulum SQL'ini yerel PostgreSQL'de doğrular.
#   scripts/verify-clean-install.sh sql/02_clean_install.sql
#
# Ne kontrol eder:
#   1) boş şemada hatasız çalışıyor mu
#   2) üst üste 3 kez çalıştırılabiliyor mu (idempotans)
#   3) hiç satır veri yazıyor mu (yazmamalı)
# Gerekli: postgresql-16 (initdb/pg_ctl/psql), `postgres` kullanıcısı.
set -euo pipefail

SQL_FILE="${1:?kullanim: $0 <clean-install.sql>}"
PGBIN=/usr/lib/postgresql/16/bin
PGDATA=${PGDATA_DIR:-/var/tmp/pgdata_cv_verify}
PORT=${PGPORT:-5434}
RUN=/var/tmp
PSQL="$PGBIN/psql -h $RUN -p $PORT -U postgres -d postgres"

say() { printf '\n== %s\n' "$*"; }

if ! su postgres -c "$PSQL -Atc 'select 1'" >/dev/null 2>&1; then
  say "yerel PostgreSQL baslatiliyor ($PGDATA, port $PORT)"
  rm -rf "$PGDATA"; mkdir -p "$PGDATA"; chown postgres:postgres "$PGDATA"; chmod 700 "$PGDATA"
  su postgres -c "$PGBIN/initdb -D $PGDATA -U postgres --auth=trust" >/dev/null
  su postgres -c "$PGBIN/pg_ctl -D $PGDATA -o '-k $RUN -p $PORT -c listen_addresses=' -l $RUN/pg_verify.log start" >/dev/null
  sleep 2
fi

HARNESS=$RUN/cv_harness.sql
cat > "$HARNESS" <<'EOS'
create schema if not exists auth;
create extension if not exists pgcrypto;
create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text,
  created_at timestamptz not null default now(),
  last_sign_in_at timestamptz);
create or replace function auth.uid() returns uuid language sql stable
  as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
create or replace function auth.jwt() returns jsonb language sql stable
  as $$ select coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb) $$;
do $$ begin
  if not exists (select 1 from pg_roles where rolname='anon') then create role anon; end if;
  if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
  if not exists (select 1 from pg_roles where rolname='service_role') then create role service_role; end if;
end $$;
grant usage on schema public, auth to anon, authenticated, service_role;
EOS
chmod 644 "$HARNESS"

cp "$SQL_FILE" "$RUN/cv_clean.sql"; chmod 644 "$RUN/cv_clean.sql"
su postgres -c "$PSQL -q -c 'drop schema if exists public cascade; create schema public;'" >/dev/null
su postgres -c "$PSQL -q -v ON_ERROR_STOP=1 -f $HARNESS" >/dev/null

for i in 1 2 3; do
  say "$i. calistirma"
  if su postgres -c "$PSQL -v ON_ERROR_STOP=1 -q -f $RUN/cv_clean.sql" 2>&1 | grep -v '^psql.*NOTICE' | grep .; then
    echo "HATA: $i. calistirma basarisiz"; exit 1
  fi
  echo "   hatasiz"
done

say "envanter"
su postgres -c "$PSQL -Atc \"
  select 'tablo   '||count(*) from pg_tables where schemaname='public'
  union all select 'view    '||count(*) from pg_views where schemaname='public'
  union all select 'fonksiyon '||count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where n.nspname='public' and not exists (select 1 from pg_depend d where d.objid=p.oid and d.deptype='e')
  union all select 'kisit   '||count(*) from pg_constraint c join pg_class r on r.oid=c.conrelid
            join pg_namespace n on n.oid=r.relnamespace where n.nspname='public'
  union all select 'indeks  '||count(*) from pg_indexes where schemaname='public'
  union all select 'politika '||count(*) from pg_policies where schemaname='public'
  union all select 'trigger '||count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid
            join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and not t.tgisinternal
  union all select 'RLS kapali tablo '||count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
            where n.nspname='public' and c.relkind='r' and not c.relrowsecurity\""

say "veri kontrolu (hepsi 0 olmali)"
ROWS=$(su postgres -c "$PSQL -Atc \"
  select coalesce(sum((xpath('/row/c/text()', query_to_xml('select count(*) as c from public.'||quote_ident(relname), false, true, '')))[1]::text::bigint), 0)
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind='r'\"")
echo "   toplam satir: $ROWS"
[ "$ROWS" = "0" ] || { echo "HATA: temiz kurulum veri yaziyor"; exit 1; }

say "SONUC: temiz kurulum gecerli — 3x idempotent, sifir veri"
