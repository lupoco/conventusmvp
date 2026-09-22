#!/usr/bin/env node
/* ============================================================
   CONVENTITY — DİL TARAMA BETİĞİ  (§7.4)

   Her .html için i18n'lenmemiş görünür metni bulur:
     1) data-i / data-ph / data-i18n taşımayan HTML metin düğümleri
     2) <script> içinde görünür (harf içeren, boşluklu) string'ler

   Amaç: bir sayfa "tamam" sayılmadan önce çıktısı O olmalı.
   Sezgisel bir araçtır — false-positive olabilir; migrasyonda
   rehber olarak kullan.

   Kullanım:
     node scripts/lang-scan.mjs                # tüm .html
     node scripts/lang-scan.mjs index.html …   # belirli dosyalar
     node scripts/lang-scan.mjs --samples 5     # örnek sayısı
   ============================================================ */
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const ROOT = process.cwd();
const args = process.argv.slice(2);
let SAMPLES = 3;
const si = args.indexOf('--samples');
if (si >= 0) { SAMPLES = parseInt(args[si + 1], 10) || 3; args.splice(si, 2); }

const SKIP_DIRS = new Set(['.git', 'node_modules', 'legal']); // legal/* stub, i18n dışı
function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    if (SKIP_DIRS.has(name)) continue;
    const p = join(dir, name);
    const st = statSync(p);
    if (st.isDirectory()) walk(p, out);
    else if (name.endsWith('.html')) out.push(p);
  }
  return out;
}

const files = args.length ? args.map(a => join(ROOT, a)) : walk(ROOT);

const hasLetter = s => /[A-Za-zÇĞİÖŞÜçğıöşü]/.test(s);
const TR = /[ğışĞİŞ]|(ç|ö|ü)/; // yalnızca bilgi amaçlı

// Bir metnin hemen solundaki açılış etiketini bul (yaklaşık).
function tagBefore(html, idx) {
  const lt = html.lastIndexOf('<', idx);
  if (lt < 0) return '';
  const gt = html.indexOf('>', lt);
  return gt < 0 ? '' : html.slice(lt, gt + 1);
}

function scanHtmlText(html) {
  // script/style bloklarını çıkar (metin taraması için)
  const stripped = html
    .replace(/<script[\s\S]*?<\/script>/gi, m => ' '.repeat(m.length))
    .replace(/<style[\s\S]*?<\/style>/gi, m => ' '.repeat(m.length));
  const hits = [];
  const re = />([^<]+)</g;
  let m;
  while ((m = re.exec(stripped))) {
    const raw = m[1];
    const text = raw.replace(/&[a-z#0-9]+;/gi, '').trim();
    if (!text || !hasLetter(text)) continue;
    if (text.length < 2) continue;
    const tag = tagBefore(stripped, m.index);
    if (/data-i\s*=|data-ph\s*=|data-i18n/.test(tag)) continue; // i18n'li
    if (/^<(option|title)/i.test(tag) === false && /^<\/(option|title)/i.test(tag)) continue;
    hits.push(text.slice(0, 60));
  }
  return hits;
}

function scanJsStrings(html) {
  const hits = [];
  const re = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
  let m;
  while ((m = re.exec(html))) {
    const js = m[1];
    // T('…') / Tf('…') içindekiler zaten i18n — bunları maskele
    const masked = js.replace(/\bTf?\s*\(\s*(['"`])[^'"`]*\1/g, ' ');
    const sre = /(['"`])((?:\\.|(?!\1)[^\\])*)\1/g;
    let s;
    while ((s = sre.exec(masked))) {
      const str = s[2];
      if (!hasLetter(str)) continue;
      if (!/\s/.test(str)) continue;             // tek kelime → çoğu teknik
      if (str.length < 4) continue;
      // CSS seçici / media query / teknik string'leri ele
      if (/[[\](){}<>]/.test(str)) continue;                 // seçici/DOM
      if (/prefers-color-scheme|data-[a-z-]+|color-scheme/.test(str)) continue;
      if (/^[\s\w./#:%,-]+$/.test(str) && !TR.test(str)) continue; // teknik ASCII
      hits.push(str.slice(0, 60));
    }
  }
  return hits;
}

let grandTotal = 0;
const rows = [];
for (const f of files) {
  let html;
  try { html = readFileSync(f, 'utf8'); } catch { continue; }
  const htmlHits = scanHtmlText(html);
  const jsHits = scanJsStrings(html);
  const total = htmlHits.length + jsHits.length;
  grandTotal += total;
  rows.push({ f: relative(ROOT, f), total, htmlHits, jsHits });
}

rows.sort((a, b) => b.total - a.total);
for (const r of rows) {
  const flag = r.total === 0 ? '✅' : '⚠️ ';
  console.log(`${flag} ${r.total.toString().padStart(4)}  ${r.f}`);
  if (r.total && SAMPLES) {
    for (const h of r.htmlHits.slice(0, SAMPLES)) console.log(`         html: ${h}`);
    for (const h of r.jsHits.slice(0, SAMPLES)) console.log(`         js  : ${h}`);
  }
}
console.log(`\nTOPLAM: ${grandTotal} işaretlenmiş metin, ${rows.length} dosya.`);
console.log(grandTotal === 0 ? 'Temiz — iş bitti.' : 'Sıfır olana dek bitmedi (§7.4).');
process.exit(0);
