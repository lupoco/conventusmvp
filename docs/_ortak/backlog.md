# Merkez Backlog

Ofisin altyapı işleri. Durum: açık · çalışılıyor · incelemede · kapandı.

| # | İş | Sorumlu | Kurucudan gereken | Durum |
|---|---|---|---|---|
| M-01 | `staging` dalı ve staging alt alan adı; ajanlar önce oraya gönderir | `devops` | Hostinger'da alt alan adı ve dal bağlantısı | açık |
| M-02 | `main` için dal koruması: doğrudan push kapalı, bir onay zorunlu | `devops` | GitHub depo ayarı | açık |
| M-03 | PR'da otomatik test ve etki özeti | `devops` | Yok | açık |
| M-04 | Migration hattı: birleştirilen `sql/` dosyaları ortam onayıyla canlıya uygulanır | `devops`, `omurga-mimari` | Supabase erişim belirtecinin GitHub gizli değerlerine eklenmesi | açık |
| M-05 | Deneme ortamı için yazma, canlı proje için salt okunur veritabanı bağlantısı | `devops` | Supabase bağlantı izni | açık |
| M-06 | Web kökünde servis edilen geliştirme dosyalarının incelenmesi (`sql/`, `scripts/`, `supabase/`) | `guvenlik-opsec` | Yok | açık |
| M-07 | Günlük özet: biten işler, onay bekleyenler, açık kararlar | `dokumantasyon` | Bildirim kanalı seçimi | açık |
| M-08 | Tasarım token'larının tek kaynakta birleştirilmesi (karar K-04) | frontend ajanları | K-04 kararı | açık |
| M-09 | Supabase ve Hostinger için yazılı çıkış planı | `devops`, `omurga-mimari` | Yok | açık |
| M-10 | Sohbetlerde üretilmiş dağınık işlerin depoya alınması | `dokumantasyon` | Dosyaların iletilmesi | açık |
