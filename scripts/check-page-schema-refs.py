#!/usr/bin/env python3
"""
Launch kapsamındaki sayfaların çağırdığı her tablo/view/RPC şemada var mı?

    python3 scripts/check-page-schema-refs.py            # sadece listeler
    python3 scripts/check-page-schema-refs.py --psql "psql -h /var/tmp -p 5434 -U postgres -d postgres"

Eksik varsa çıkış kodu 1. "Tablo yok" hatası kullanıcıya gitmeden yakalanır.
Yarım sayfalar (go-and-meet, gm-provider, product-studio, conventus/settings)
launch kapsamı dışında, bu yüzden listede yok.
"""
import argparse, pathlib, re, subprocess, sys

PAGES = """
index.html login.html register.html settings.html forgot-password.html reset-password.html
core.html verified.html verified-directory.html admin/index.html dashboard/index.html
platforms/conventus/index.html platforms/conventus/start.html platforms/conventus/communities.html
platforms/conventus/community.html platforms/conventus/community-admin.html
platforms/conventus/event-studio.html platforms/conventus/new-event.html
platforms/conventus/event-manage.html platforms/conventus/my-events.html
platforms/conventus/my-event.html platforms/conventus/applications.html
platforms/conventus/agenda.html platforms/conventus/programme.html
platforms/conventus/announcements.html platforms/conventus/register-conventus.html
platforms/conventus/register.html platforms/conventus/handbook.html
platforms/conventus/go-and-test.html platforms/conventus/gm-plan.html
""".split()

FROM = re.compile(r"""\.from\(\s*['"]([A-Za-z0-9_]+)['"]""")
RPC = re.compile(r"""\.rpc\(\s*['"]([A-Za-z0-9_]+)['"]""")

HAVE_SQL = (
    "select 'T '||tablename from pg_tables where schemaname='public' "
    "union all select 'T '||viewname from pg_views where schemaname='public' "
    "union all select 'R '||proname from pg_proc p "
    "join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--psql', help='psql komutu; verilmezse sadece listeler')
    a = ap.parse_args()

    root = pathlib.Path(__file__).resolve().parent.parent
    tables, rpcs, missing_pages = set(), set(), []
    for f in PAGES:
        p = root / f
        if not p.exists():
            missing_pages.append(f); continue
        s = p.read_text(encoding='utf-8')
        tables |= set(FROM.findall(s))
        rpcs |= set(RPC.findall(s))

    print('sayfa      : %d' % (len(PAGES) - len(missing_pages)))
    print('tablo/view : %d' % len(tables))
    print('RPC        : %d' % len(rpcs))
    for f in missing_pages:
        print('EKSIK SAYFA: %s' % f)

    if not a.psql:
        for t in sorted(tables): print('  T %s' % t)
        for r in sorted(rpcs): print('  R %s' % r)
        return 1 if missing_pages else 0

    out = subprocess.run(a.psql.split() + ['-Atc', HAVE_SQL],
                         capture_output=True, text=True)
    if out.returncode:
        print('psql hatasi:\n' + out.stderr); return 2
    have = set(out.stdout.split('\n'))
    missing = sorted({'T ' + t for t in tables} - have) + sorted({'R ' + r for r in rpcs} - have)
    if missing or missing_pages:
        print('\nSEMADA YOK:')
        for m in missing:
            print('  %-11s %s' % ('tablo/view:' if m[0] == 'T' else 'RPC:', m[2:]))
        return 1
    print('\n✓ cagrilan her tablo/view/RPC semada var')
    return 0


if __name__ == '__main__':
    sys.exit(main())
