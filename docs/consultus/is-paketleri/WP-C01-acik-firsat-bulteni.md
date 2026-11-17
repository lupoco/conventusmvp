# WP-C01 — Açık Fırsat Bülteni: sayfa, abonelik ve haftalık güncelleme

- **Modül:** Consultus
- **Durum:** açık; K-01 ve K-02 kararını bekliyor (`docs/_ortak/kararlar.md`)
- **Risk sınıfı:** yüksek (abone listesi kişisel veridir)
- **Dal:** `ofis/consultus-bulten`

## Amaç

Savunma sanayii firmaları; NATO, Avrupa Komisyonu ve Ukrayna'nın kendilerine
açık ihale, çağrı ve faaliyetlerini tek sayfada, kaynağıyla görür ve isterse
haftalık e-postaya abone olur.

## Kapsam

Çalışan bir prototip vardır (tek dosya; harita, takvim, uygunluk tablosu, dört
dil, koyu ve açık tema, abonelik formunun önizlemesi). Bu iş paketi prototipi
ürüne çevirir.

- **Frontend:** prototipin depoya alınması; içerik verisinin sayfadan ayrı bir
  veri dosyasına taşınması; depo kurallarına uyum (`cv-config.js`, `cv-core.js`,
  kökten mutlak yollar, sürüm rozeti); tasarım token'larının K-04 kararına göre
  bağlanması.
- **Backend:** abone tablosu, çift onay, tek tıkla ayrılma, rıza kaydı; haftalık
  e-posta gönderimi için Edge Function.
- **Test:** aşağıdaki kabul kriterleri.

Kapsam dışı: firma profilleri, eşleştirme, ücretli herhangi bir hizmet.

## Kabul kriterleri

1. Her kayıt en az bir kaynak bağlantısı, durum ve kimlerin başvurabileceği
   bilgisini gösterir.
2. Tarihi açıklanmamış kayıt tarih gösterilmeden "beklenen" olarak görünür.
3. Son başvuru tarihi geçen kayıt "kapandı" olarak görünür.
4. Haritadaki yaklaşık çizimler "yaklaşık" diye etiketlidir.
5. Sayfa dört dilde aynı kayıtları gösterir; hiçbir dilde eksik anahtar yoktur.
6. Sayfa "hiçbir kurum adına yayımlanmaz" notunu taşır.
7. Abonelik yalnız e-postadaki doğrulama bağlantısına tıklanınca etkinleşir.
8. Her e-postada tek tıkla ayrılma bağlantısı vardır ve çalışır.
9. Anonim kullanıcı abone listesini okuyamaz; yalnız kendi kaydını oluşturabilir.
10. Haftalık güncelleme yalnız veri dosyasını değiştirir; sayfa kodu değişmez.

## Veri ve yetki etkisi

Yeni tablo: bülten aboneleri (e-posta, dil, ilgi alanı, doğrulama durumu, rıza
zamanı, ayrılma belirteci). RLS: ekleme anonim kullanıcıya açık, okuma ve
güncelleme yalnız yöneticiye. Tasarımı omurga mimarı yazar.

## Etik kapısı

- Madde 1: içerik yalnız açık kaynaktan derlenir; ikincil kaynak belirtilir.
- Madde 2: bülten herkese açıktır; abonelik kimseye öncelik sağlamaz.
- Madde 4: sayfa hiçbir kurum adına konuşmaz.
- Madde 5 ve 6: abone kaydı yalnız kişinin kendi başvurusuyla ve açık rızasıyla
  oluşur. Yönetici bir kişiyi kendi adına abone yapamaz; yalnız davet gönderebilir.
- Türkiye'de ticari elektronik ileti ve ileti yönetim sistemi kaydı gerekip
  gerekmediği hukuki görüşle teyit edilir.

## Çalışacak ajanlar (sırayla)

1. `omurga-mimari`: abone tablosu ve RLS tasarımı.
2. `consultus-backend`: migration, rollback, doğrulama; Edge Function.
3. `consultus-frontend`: prototipin depoya alınması ve veri dosyası.
4. `consultus-test`: kabul kriterleri.
5. `guvenlik-opsec` ve `uyum-ihracat`: inceleme.
6. `entegrasyon-qa`: son kontrol.

## Karar gerekiyor

K-01 (yayın yeri ve abone verisinin duracağı proje) ve K-02 (deneme ortamının
yeri). Seçenekler ve öneri `docs/_ortak/kararlar.md` içindedir.
