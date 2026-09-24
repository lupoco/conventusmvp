#!/usr/bin/env bash
# sql/05_harden_grants.sql'in ONCE/SONRA kanitini uretir.
#   scripts/test-harden-grants.sh
# Gerekli: scripts/verify-clean-install.sh ile kurulmus yerel PostgreSQL
# (varsayilan /var/tmp/pgdata_cv_verify, port 5434).
set -euo pipefail

PGBIN=/usr/lib/postgresql/16/bin
PGDATA=${PGDATA_DIR:-/var/tmp/pgdata_cv_verify}
PORT=${PGPORT:-5434}
RUN=/var/tmp
PSQL="$PGBIN/psql -h $RUN -p $PORT -U postgres -d postgres"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! su postgres -c "$PSQL -Atc 'select 1'" >/dev/null 2>&1; then
  su postgres -c "$PGBIN/pg_ctl -D $PGDATA -o '-k $RUN -p $PORT -c listen_addresses=' -l $RUN/pg_harden.log start" >/dev/null
  sleep 2
fi

for f in sql/04_access_requests.sql sql/09_registration_wizard.sql sql/05_harden_grants.sql sql/05_harden_grants_ROLLBACK.sql scripts/test-harden-grants.sql; do
  cp "$ROOT/$f" "$RUN/$(basename "$f")"; chmod 644 "$RUN/$(basename "$f")"
done

run() { su postgres -c "$PSQL -q -v ON_ERROR_STOP=1 -f $RUN/$1" 2>&1; }

echo "== 0) 02'deki yetki durumuna don (ROLLBACK) + 04 ve 09'u yeniden uygula =="
# ROLLBACK her tabloya `grant all to anon` veriyor; 05 SELECT'e DOKUNMADIGI icin
# kendi basina yetmez. Kendi `revoke ... from anon` satirlari olan her dosya
# tekrar calistirilmali: 04 (erisim talepleri) ve 09 (onay/parkur tablolari).
# Ilk surumde 09 unutulmustu ve test-registration-wizard.sql "anon onaylari
# okudu" diye patladi — dogru yakaladi.
run 05_harden_grants_ROLLBACK.sql >/dev/null
run 04_access_requests.sql >/dev/null
run 09_registration_wizard.sql >/dev/null
echo "   tamam"

echo
echo "########## ONCE — 05 uygulanmadan ##########"
run test-harden-grants.sql | grep -v '^$' | grep -v '^ *bolum *$' | grep -v '^-\+$' | grep -v 'row)$' | grep -v 'rows)$'

echo
echo "== 1) 05_harden_grants.sql uygulaniyor =="
run 05_harden_grants.sql | sed -n '1,200p'

echo
echo "########## SONRA — 05 uygulandiktan sonra ##########"
run test-harden-grants.sql | grep -v '^$' | grep -v '^ *bolum *$' | grep -v '^-\+$' | grep -v 'row)$' | grep -v 'rows)$'

echo
echo "== 2) idempotans: 05 ikinci kez =="
run 05_harden_grants.sql >/dev/null && echo "   hatasiz"
