#!/usr/bin/env python3
"""
01_dump_org_schema.sql çıktısını (CSV ya da düz metin) conventity.com temiz
kurulumu için tek, idempotent, SEED'SİZ bir SQL dosyasına dönüştürür.

    python3 scripts/dump-to-clean-install.py <dump.csv> -o sql/02_clean_install.sql

Neyi değiştirir:
  • kısıtlar (PK/UNIQUE/CHECK) ve yabancı anahtarlar  -> katalog kontrollü DO döngüsü
  • CREATE INDEX                                      -> CREATE INDEX IF NOT EXISTS
  • CREATE TRIGGER                                    -> önce DROP TRIGGER IF EXISTS
  • create policy                                     -> önce DROP POLICY IF EXISTS
  • ~1100 satır GRANT                                 -> tüm public tablo/view'lara tek döngü
  • 74 satır "enable row level security"              -> tüm public tablolara tek döngü
  • satır sayıları                                    -> dosya sonunda yorum (VERİ KOPYALANMAZ)

Veri (INSERT) hiçbir koşulda üretilmez — omurga boş kurulur.
"""
import argparse, csv, io, re, sys

SECTION = re.compile(r'^--\s*=+\s*(-?\d+)\s*·')
CONSTRAINT = re.compile(
    r'^alter table public\.(?P<tbl>\S+) add constraint (?P<con>\S+) (?P<def>.*);$', re.S)
INDEX = re.compile(r'^CREATE (UNIQUE )?INDEX ', re.I)
TRIGGER = re.compile(r'^CREATE TRIGGER (?P<name>\S+)\s.*?\sON (?P<tbl>\S+)\s', re.I | re.S)
POLICY = re.compile(r'^create policy (?P<name>"[^"]*"|\S+) on (?P<tbl>"[^"]*"|\S+) as ', re.S)


def read_statements(path):
    """CSV (tek kolon) ya da düz metin -> ifade listesi."""
    raw = open(path, encoding='utf-8-sig').read()
    # CSV mi? İlk satır başlık ya da tırnakla başlıyorsa csv olarak dene.
    try:
        rows = list(csv.reader(io.StringIO(raw)))
        if rows and all(len(r) <= 1 for r in rows):
            out = [r[0] for r in rows if r]
            if out and out[0].strip().lower() in ('ddl', 'ddl_out'):
                out = out[1:]
            return out
    except csv.Error:
        pass
    return raw.split('\n')


def split_sections(stmts):
    """İfadeleri döküm bölümlerine ayır (bölüm no -> ifadeler)."""
    sections, cur = {}, None
    for s in stmts:
        head = s.lstrip('\n')
        m = SECTION.match(head)
        if m:
            cur = int(m.group(1))
            sections.setdefault(cur, [])
            continue
        if cur is None:
            continue
        if not s.strip() or s.strip().startswith('-- conventity.ORG'):
            continue
        sections[cur].append(s.strip('\n'))
    return sections


def dollar_tag(text):
    """İçeriğe çakışmayan bir dollar-quote etiketi seç."""
    for tag in ('$d$', '$dd$', '$ddd$', '$cv$', '$cv1$', '$cv2$'):
        if tag not in text:
            return tag
    raise SystemExit('dollar-quote etiketi bulunamadi')


def constraint_loop(rows, title, note):
    """(tablo, kısıt, tanım) üçlülerini idempotent DO döngüsüne çevir."""
    if not rows:
        return ''
    items = []
    for tbl, con, dfn in rows:
        tag = dollar_tag(dfn)
        items.append("    (%s, %s, %s%s%s)" % (
            quote_lit(tbl), quote_lit(con), tag, dfn, tag))
    return (
        "-- %s\n"
        "do $cvblock$\n"
        "declare r record;\n"
        "begin\n"
        "  for r in select * from (values\n%s\n  ) v(tbl, con, def) loop\n"
        "    if not exists (\n"
        "      select 1 from pg_constraint c\n"
        "      join pg_class rel on rel.oid = c.conrelid\n"
        "      join pg_namespace n on n.oid = rel.relnamespace\n"
        "      where n.nspname = 'public' and rel.relname = r.tbl and c.conname = r.con\n"
        "    ) then\n"
        "      execute format('alter table public.%%I add constraint %%I %%s', r.tbl, r.con, r.def);\n"
        "    end if;\n"
        "  end loop;\n"
        "end $cvblock$;\n"
        "-- %s\n" % (title, ',\n'.join(items), note))


def quote_lit(s):
    return "'" + s.replace("'", "''") + "'"


def unquote_ident(s):
    return s[1:-1].replace('""', '"') if s.startswith('"') else s


def strip_schema(s):
    return s[len('public.'):] if s.startswith('public.') else s



VIEW_NAME = re.compile(r'^create or replace view (?P<name>"[^"]*"|\S+) as', re.S)


def wrap_type(stmt):
    """`create type` IF NOT EXISTS bilmez — duplicate_object'i yut."""
    return ("do $cvblock$\nbegin\n  %s\nexception when duplicate_object then null;\nend $cvblock$;"
            % stmt.strip())


def topo_sort_views(stmts):
    """View'ları bağımlılık sırasına diz: alfabetik sıra view-üstüne-view'da kırılır."""
    named = []
    for s in stmts:
        m = VIEW_NAME.match(s.strip())
        if not m:
            raise SystemExit('view ayristirilamadi: %r' % s[:120])
        named.append((strip_schema(unquote_ident(m.group('name'))), s))
    names = {n for n, _ in named}

    def deps(name, body):
        # gövdede geçen DİĞER view adları (tam kelime)
        return {o for o in names
                if o != name and re.search(r'\b%s\b' % re.escape(o), body)}

    pending, done, out = list(named), set(), []
    guard = 0
    while pending:
        guard += 1
        if guard > len(named) + 5:
            raise SystemExit('view bagimliliginda dongu: %s' % [n for n, _ in pending])
        nxt = []
        for name, body in pending:
            if deps(name, body) <= done:
                out.append(body); done.add(name)
            else:
                nxt.append((name, body))
        if len(nxt) == len(pending):
            raise SystemExit('view bagimliligi cozulemedi: %s' % [n for n, _ in nxt])
        pending = nxt
    return out


HEADER = """\
-- ============================================================================
-- 02_clean_install.sql  ·  conventity.com — TEMİZ KURULUM
--
-- Kaynak: conventity.org `public` şemasının salt-okunur DDL dökümü
--         (sql/01_dump_org_schema.sql ile alındı).
-- Üretim: scripts/dump-to-clean-install.py — elle düzenleme YAPMA,
--         döküm değişirse scripti yeniden çalıştır.
--
-- NE YAPAR: omurgayı + Conventus/Convexus/Connectus şemasını BOŞ kurar.
-- NE YAPMAZ: hiçbir INSERT yok. 147 org, convexus havuzu, form şablonları,
--            demo veri — hiçbiri taşınmaz. (Dosya sonundaki yorum bloğu
--            .org'da hangi tablonun kaç satır taşıdığını gösterir.)
--
-- NEREDE ÇALIŞIR: conventity-prod (tstlireeidnpchadgjly) → SQL Editor.
--                 .org'da ÇALIŞTIRMA.
--
-- SONRASINDA: 02, .org'un yetki satirlarini da sadik biçimde tasir —
--             her tabloda `grant all to anon`. Bu dosyayi her calistirdiktan
--             sonra `sql/05_harden_grants.sql` de calistirilmali; yoksa anon
--             rolu, RLS'i atlayan view'ler uzerinden yazma yetkisi kazanir.
--
-- İdempotent: tekrar çalıştırılabilir, ikinci çalıştırma hiçbir şey değiştirmez.
-- SQL Editor tek transaction çalıştırır: bir satır patlarsa hepsi geri alınır.
-- ============================================================================

-- ---- YANLIŞ PROJE KORUMASI -------------------------------------------------
-- İki proje açıkken sekmeler karışıyor. Bu dosya .org'da çalışırsa idempotent
-- olduğu için sessizce "Success" der ve HİÇBİR ŞEY yapmaz — kurulum yapıldı
-- sanırsın. .org'un seed verisi burada parmak izi olarak kullanılıyor:
-- temiz kurulumda bu tabloların hepsi boş.
do $cvguard$
declare n_prof bigint := 0; n_org bigint := 0; n_ass bigint := 0;
begin
  if to_regclass('public.convexus_profiles') is not null then
    select count(*) into n_prof from public.convexus_profiles;
  end if;
  if to_regclass('public.conventity_orgs') is not null then
    select count(*) into n_org from public.conventity_orgs;
  end if;
  if to_regclass('public.conventus_selection_assessments') is not null then
    select count(*) into n_ass from public.conventus_selection_assessments;
  end if;
  if n_prof >= 100 or n_org >= 100 or n_ass >= 100 then
    raise exception E'\n\n  YANLIS PROJE: convexus_profiles=%, conventity_orgs=%, '
      'conventus_selection_assessments=%.\n'
      '  Bu conventity.ORG gibi gorunuyor (shbwylrwpioqypbdhjgn) — orada zaten '
      'her sey kurulu,\n  bu dosya orada sessizce hicbir sey yapmaz.\n'
      '  Dogru proje: https://supabase.com/dashboard/project/tstlireeidnpchadgjly/sql/new\n'
      '  Hicbir sey yazilmadi.\n', n_prof, n_org, n_ass;
  end if;
end $cvguard$;

-- ---- Ön koşul: Supabase rolleri ve auth şeması hazır olmalı ---------------
do $cvblock$
begin
  if to_regprocedure('auth.uid()') is null then
    raise exception 'auth.uid() yok — bu script Supabase projesinde calistirilmali.';
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    raise exception 'authenticated rolu yok — bu script Supabase projesinde calistirilmali.';
  end if;
end $cvblock$;

grant usage on schema public to anon, authenticated, service_role;
"""

RLS_LOOP = """\
-- ===================== 8 · RLS =====================
-- .org'da public şemasındaki HER tabloda RLS açık. Tek tek yazmak yerine
-- döngü: yeni tablo eklendiğinde de atlanmaz.
do $cvblock$
declare r record;
begin
  for r in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', r.tablename);
  end loop;
end $cvblock$;
"""

GRANT_LOOP = """\
-- ===================== 10 · YETKILER =====================
-- PostgREST rolleri tablo ayrıcalığı olmadan RLS'e hiç ulaşamaz.
-- .org'da üç role de public'teki tüm tablo/view üzerinde tam yetki verilmiş;
-- gerçek sınır RLS politikalarıdır (yukarıda).
do $cvblock$
declare r record;
begin
  for r in select tablename as rel from pg_tables where schemaname = 'public'
           union all
           select viewname  as rel from pg_views  where schemaname = 'public' loop
    execute format('grant all on public.%I to anon, authenticated, service_role', r.rel);
  end loop;
end $cvblock$;

alter default privileges in schema public
  grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on sequences to anon, authenticated, service_role;
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('dump')
    ap.add_argument('-o', '--out', required=True)
    args = ap.parse_args()

    sec = split_sections(read_statements(args.dump))
    out = [HEADER]

    def emit(title, num, transform=None):
        body = sec.get(num, [])
        if not body:
            return
        out.append('-- ===================== %s =====================' % title)
        for s in body:
            out.append((transform(s) if transform else s))
        out.append('')

    # -1 eklentiler (yorum), 0 tipler, 1 diziler, 2 tablolar
    if sec.get(-1):
        out.append('-- ---- .org\'da kurulu eklentiler (bilgi; yeni proje kendi setiyle gelir) ----')
        out.extend(sec[-1]); out.append('')
    emit('0 · TIPLER', 0, wrap_type)
    emit('1 · DIZILER', 1)
    emit('2 · TABLOLAR', 2)

    # 3 kısıtlar + 11 yabancı anahtarlar -> DO döngüsü
    def parse_cons(num):
        rows = []
        for s in sec.get(num, []):
            m = CONSTRAINT.match(s.strip())
            if not m:
                raise SystemExit('kisit ayristirilamadi: %r' % s[:120])
            rows.append((m.group('tbl'), m.group('con'), m.group('def')))
        return rows

    out.append(constraint_loop(
        parse_cons(3), '===================== 3 · PK / UNIQUE / CHECK =====================',
        '-- (kısıt sonu)'))
    emit('4 · INDEKSLER', 4, lambda s: re.sub(
        r'^CREATE (UNIQUE )?INDEX ', lambda m: 'CREATE %sINDEX IF NOT EXISTS ' % (m.group(1) or ''),
        s, flags=re.I) if INDEX.match(s) else s)
    emit('5 · FONKSIYONLAR', 5)
    sec[6] = topo_sort_views(sec.get(6, []))
    emit('6 · VIEWLAR', 6)

    def trg(s):
        m = TRIGGER.match(s)
        if not m:
            raise SystemExit('trigger ayristirilamadi: %r' % s[:120])
        return 'drop trigger if exists %s on %s;\n%s' % (m.group('name'), m.group('tbl'), s)
    emit('7 · TRIGGERLAR', 7, trg)

    out.append(RLS_LOOP)

    def pol(s):
        m = POLICY.match(s)
        if not m:
            raise SystemExit('politika ayristirilamadi: %r' % s[:120])
        return 'drop policy if exists %s on %s;\n%s' % (m.group('name'), m.group('tbl'), s)
    emit('9 · POLITIKALAR', 9, pol)

    out.append(GRANT_LOOP)

    out.append(constraint_loop(
        parse_cons(11),
        '============ 11 · YABANCI ANAHTARLAR (en sonda) ============',
        '-- (yabanci anahtar sonu)'))

    if sec.get(12):
        out.append('-- ============================================================================')
        out.append('-- .org\'daki satır sayıları — SADECE BİLGİ. Bu dosya hiçbirini kopyalamaz.')
        out.append('-- Şablon/referans verisi taşıyan tablolar (form alanları, puanlama boyutları,')
        out.append('-- focus area / domain sözlükleri) ileride ayrı bir seed dosyasıyla gelecek.')
        out.append('-- ============================================================================')
        out.extend(sec[12])

    open(args.out, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
    print('yazildi: %s' % args.out)
    for k in sorted(sec):
        print('  bolum %-3s %4d ifade' % (k, len(sec[k])))


if __name__ == '__main__':
    main()
