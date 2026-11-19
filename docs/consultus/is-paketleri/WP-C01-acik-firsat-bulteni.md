# WP-C01 — Açık Fırsat Bülteni: e-posta aboneliği altyapısı

- **Modül:** Consultus
- **Durum:** açık; K-01 kararını bekliyor (`docs/_ortak/kararlar.md`)
- **Risk sınıfı:** yüksek (abone listesi kişisel veridir)
- **Dal:** `ofis/consultus-bulten-abonelik`

## Amaç

Bülteni okuyan kişi e-posta adresini bırakır, adresini doğrular ve her hafta
yeni sayının duyurusunu alır; istediği an tek tıkla ayrılır.

## Kapsam

Bülten sayfası ve haftalık içerik bu deponun işi değildir: ayrı depoda
(`lupoco/conventity-bulten`) ve `conventity.org` adresinde, kendi ofisiyle
yürür (karar 2026-11-18). İlk yayın aboneliksizdir. Bu iş paketi aboneliğin
sunucu tarafını kurar; formu bülten ofisi sayfaya ekler.

- **Backend:** abone tablosu, çift onay, tek tıkla ayrılma, rıza kaydı;
  abonelik ve ayrılma uç noktaları; haftalık gönderim için Edge Function.
- **Bülten ofisine verilecek sözleşme:** uç nokta adresleri, istek ve yanıt
  biçimi, izin verilecek kaynak (`https://conventity.org`).
- **Test:** aşağıdaki kabul kriterleri.

Kapsam dışı: firma profilleri, eşleştirme, ücretli herhangi bir hizmet;
kartvizitten kişi ekleme (karar K-03).

## Kabul kriterleri

1. Abonelik yalnız e-postadaki doğrulama bağlantısına tıklanınca etkinleşir.
2. Her e-postada tek tıkla ayrılma bağlantısı vardır ve çalışır.
3. Anonim kullanıcı abone listesini okuyamaz; yalnız kendi kaydını oluşturabilir.
4. Aynı adresle yinelenen başvuru yeni kayıt açmaz ve adresin kayıtlı olup
   olmadığını belli etmez.
5. Rıza metni, zamanı ve dili kayıtla birlikte saklanır.
6. Ayrılan kişinin adresi gönderim listesinden o an çıkar.
7. Uç noktalar yalnız `https://conventity.org` kaynağından gelen isteği kabul
   eder ve hız sınırı uygular.
8. Yönetici bir kişiyi kendi adına abone yapamaz; yalnız davet gönderebilir.

## Veri ve yetki etkisi

Yeni tablo: bülten aboneleri (e-posta, dil, ilgi alanı, doğrulama durumu, rıza
zamanı ve metni, ayrılma belirteci). RLS: ekleme anonim kullanıcıya açık, okuma
ve güncelleme yalnız yöneticiye. Tasarımı omurga mimarı yazar.

## Etik kapısı

- Madde 2: abonelik herkese açıktır ve kimseye öncelik sağlamaz.
- Madde 5 ve 6: abone kaydı yalnız kişinin kendi başvurusuyla ve açık rızasıyla
  oluşur.
- Türkiye'de ticari elektronik ileti ve ileti yönetim sistemi kaydı gerekip
  gerekmediği hukuki görüşle teyit edilir.

## Çalışacak ajanlar (sırayla)

1. `omurga-mimari`: abone tablosu ve RLS tasarımı.
2. `consultus-backend`: migration, rollback, doğrulama; uç noktalar ve gönderim.
3. `consultus-test`: kabul kriterleri.
4. `guvenlik-opsec` ve `uyum-ihracat`: inceleme.
5. `entegrasyon-qa`: son kontrol.

## Karar gerekiyor

K-01: abone listesinin duracağı proje ve gönderim hizmeti. Seçenekler ve öneri
`docs/_ortak/kararlar.md` içindedir.
