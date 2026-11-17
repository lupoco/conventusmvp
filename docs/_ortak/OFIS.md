# Conventity Ajan Ofisi

Bu depoda geliştirme işi ofis düzeniyle yürür. Ana oturum **Genel Müdür**'dür:
işi iş paketine böler ve `.claude/agents/` altındaki ajanlara dağıtır. Kurucunun
rolü onaylamaktır; SQL, kod, test ve belgeyi ajanlar yürütür.

## Nasıl başlatılır

Claude'da bu depoya bağlı bir Code oturumu açın ve işi yazın. Telefondan da
çalışır; bilgisayarın açık olması gerekmez.

```
Ofis: Consultus WP-C01'i başlat.
Ofis: kayıt formuna telefon alanı ekle.
Ofis: bu haftanın devir notunu yaz.
```

## Genel Müdür (ana oturum) ne yapar

1. İşi okur, hangi modüle ait olduğunu belirler.
2. Modül yöneticisine iş paketini ve kabul kriterlerini yazdırır.
3. Ajanları sırayla çalıştırır (aşağıdaki akış). Birbirine dokunmayan işler
   aynı anda yürüyebilir.
4. Dalı gönderir, PR açar. PR açıklamasında iş paketi, test sonucu, risk sınıfı
   ve etki özeti bulunur.
5. Dokümantasyon ajanına backlog'u ve karar kaydını güncelletir.

İki dosyayı geçmeyen, şema ve yetki içermeyen düzeltmeyi Genel Müdür doğrudan
yapabilir. Bunun dışındaki her kod işi ajanlara gider.

## İş akışı

| Sıra | Kim | Çıktı |
|---|---|---|
| 1 | Modül yöneticisi | İş paketi ve kabul kriterleri |
| 2 | Omurga mimarı (şema ya da yetki varsa) | ADR ve migration tasarımı |
| 3 | Backend | Migration, rollback, doğrulama sorgusu, RPC ya da Edge Function |
| 4 | Frontend | Sayfa ve yerelleştirme |
| 5 | Test | Kabul kriterlerine göre testler ve sonuçları |
| 6 | Güvenlik ve uyum (gerekiyorsa) | Bulgular; GEÇTİ ya da DURDUR |
| 7 | Entegrasyon QA | Son kontrol, etki analizi, risk sınıfı |
| 8 | Genel Müdür | PR |
| 9 | Kurucu | Onay |

## Kurucuya gelen dört durum

1. Canlıya giden PR (`main` dalına birleştirme).
2. Dışarıya giden iş: e-posta, yayın, başvuru.
3. Geri alınamaz işlem: veri silme, canlı şema değişikliği.
4. Kapsam değişikliği ve açık karar.

Onaylar günde tek paket hâlinde sunulur. Yalnız yüksek riskli işler anında sorulur.

## Risk sınıfı

- **Düşük:** yalnız metin, stil ya da belge; şema ve yetki yok.
- **Orta:** yeni sayfa ya da yeni tablo; mevcut yetki yapısına dokunmuyor.
- **Yüksek:** `conventity_roles`, RLS, kimlik doğrulama, `.htaccess`, kişisel veri
  ya da geri alınamaz işlem.

## Kadro (etkin)

| Ofis | Ajan | Ne yapar |
|---|---|---|
| Merkez | Genel Müdür (ana oturum) | İşi böler, dağıtır, PR açar |
| Merkez | `omurga-mimari` | Şema, RLS ve modüller arası veri akışı tasarımı; ADR |
| Merkez | `entegrasyon-qa` | PR öncesi son kontrol, etki analizi, risk sınıfı |
| Merkez | `dokumantasyon` | Karar kaydı, backlog, devir notu |
| Merkez | `devops` | Dal düzeni, CI, staging, deploy, `.htaccess` |
| Merkez | `guvenlik-opsec` | Güvenlik incelemesi |
| Merkez | `uyum-ihracat` | Etik kapısı ve uyum incelemesi |
| Conventus | `conventus-yonetici` | İş paketi ve backlog |
| Conventus | `conventus-backend` | SQL, RLS, RPC, Edge Function |
| Conventus | `conventus-frontend` | `/platforms/conventus/` sayfaları |
| Conventus | `conventus-test` | Testler |
| Consultus | `consultus-yonetici` | İş paketi ve backlog |
| Consultus | `consultus-backend` | Bülten verisi, abonelik, gönderim |
| Consultus | `consultus-frontend` | `/platforms/consultus/` sayfaları, bülten |
| Consultus | `consultus-test` | Testler |

## Sırada bekleyen ofisler

Convexus, Connectus, Convergens ve ConventLab ofisleri; Cognis; merkez iş
geliştirme; Conventus alan uzmanları (kayıt, protokol, lojistik, saha, veri
koruma, Scriba); büyüme (içerik, araştırmacı).

Bir ofis, ilk iş paketi açıldığında etkinleştirilir: `.claude/agents/<ad>.md`
dosyası eklenir (ad, ne zaman kullanılacağını söyleyen açıklama, araçlar, rol
metni) ve bu tabloya satır yazılır. Görevi olmayan ajan tanımlanmaz.

## Bugünkü sınırlar

Altyapı kurulana kadar ofis şu sınırlarla çalışır; kuracak işler
`docs/_ortak/backlog.md` içindedir.

- **Staging yok.** Doğrulama yerelde ve testlerle yapılır. PR `main` dalına
  açılır; birleştirme canlıya çıkış demektir.
- **Ajanlar canlı Supabase'e yazmaz.** Migration PR ile gelir; canlıya kurucunun
  onayıyla uygulanır.
- **Otomatik CI yok.** Testleri entegrasyon QA koşar ve çıktısını PR'a yazar.
