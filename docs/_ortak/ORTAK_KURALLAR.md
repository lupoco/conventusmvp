# Ortak Kurallar

Bütün ajanlar için geçerlidir. Öncelik sırası: etik kapısı
(`ETIK_KAPISI.md`), bu dosya, `CLAUDE.md` içindeki teknik kurallar, iş paketi.

## 1. Depoya girmeyenler

- Resmî görev belgeleri, notları ve yazışmaları; kısıtlı ya da gizli bilgi.
- Başka kurumların iç verisi; sahibinin açıkça vermediği firma ve kişi bilgisi.
- Gizli anahtarlar: `sb_secret_…`, servis anahtarı, erişim belirteci, parola.

Böyle bir girdi görülürse kullanılmaz ve Genel Müdür'e bildirilir.

Bu depo herkese açıktır. Belgelere ve commit mesajlarına kişisel bilgi, resmî
görev ayrıntısı ya da iç yazışma yazılmaz.

## 2. Ajanların yapmadıkları

- `main` dalına push.
- Canlı Supabase'e yazma.
- Dışarıya e-posta ya da mesaj gönderme, yayın yapma, başvuru gönderme.
- Veri silme ve geri alınamaz işlemler.

Bunlar kurucunun onayıyla yapılır.

## 3. Dal ve PR düzeni

- Dal adı: `ofis/<modül>-<kısa-ad>`.
- Commit mesajı Türkçe ve kısadır; ne değiştiğini söyler.
- PR açıklaması: iş paketi bağlantısı, yapılan değişiklik, test sonucu, risk
  sınıfı, etkilenen tablo ve sayfalar, canlıya uygulanacak SQL varsa sırası.

## 4. "Bitti" ne demek

1. Kabul kriterlerinin her biri doğrulandı.
2. Test raporu var; koşulamayan test açıkça yazıldı.
3. Entegrasyon QA GEÇTİ verdi.
4. Yüksek riskli işte güvenlik ve uyum incelemesi yapıldı.
5. Backlog ve karar kaydı güncel.

## 5. Öneri ve karar

Yapay zekâ çıktısı öneridir. Karar insan onayıyla verilir ve
`docs/_ortak/kararlar.md` dosyasına tarihle yazılır.

## 6. Dil

İç ve teknik belgeler Türkçedir. Kullanıcıya dönük metin Türkçe ve İngilizce
yazılır. Bülten ayrı depoda yürür ve dört dildedir (Türkçe, İngilizce, Fransızca,
Almanca).
