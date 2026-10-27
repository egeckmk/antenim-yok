# Antenim Yok — Sprint planı

> Kaynak: Ege'nin "Beyin" kasası. İlerleme burada işaretlenir.

## Sprintler
Her sprint ≈ 1 akşam / 2–3 saat. Her sprint sonunda çalışan bir exe + kısa test.

### Sprint 0 — Hazırlık & tasarım (kod yok)
- [x] İstasyon listesi (9): Alem FM, Best FM, Show Radyo, Power FM, Metro FM, Virgin Radio Türkiye, Power Türk, Radyo Fenomen, Kafa Radyo
- [x] Akış URL'leri bulundu → [stations.json](stations.json) v1 (9 istasyon, yedek akışlı; `unverified` olanlar Sprint 1'de denenecek; Power Türk, Fenomen, Kafa logosu yok)
- [x] Uygulamanın adı: **Antenim Yok** ✅ (repo: `antenim-yok`)
- [ ] Ana pencere + mini pencere + tepsi menüsü wireframe'i (onay)
- [ ] GitHub'da kişisel repo `egeckmk/antenim-yok`, solution iskeleti
- [ ] `native-app-ui` skill'ini repoya `.claude/skills/` altına kopyala
- [ ] `native-app-ui` skill'ini repoya `.claude/skills/` altına kopyala

### Sprint 1 — Çalan MVP
- [ ] `stations.json` uygulamaya gömülü; istasyon listesi
- [ ] Tıkla → çal; çal/durdur; ses ayarı
- [ ] Akış yedeği: ilki çalmazsa `streams` listesindeki sonrakine geç
- [ ] Durumlar: bağlanıyor / çalıyor / hata ("yayına ulaşılamadı")
- [ ] `.pls`/`.m3u` → gerçek URL çözümleme (+ test)
- **Bitti:** İşte 5 istasyon çalıyor.

### Sprint 2 — Windows entegrasyonu
- [ ] SMTC: klavye medya tuşları, Windows ses penceresinde istasyon adı + logo
- [ ] Tepsi simgesi; kapatınca tepside çalmaya devam
- [ ] Tek örnek (ikinci açılışta mevcut pencere öne gelir)
- [ ] Son istasyon + ses seviyesi hatırlanır
- [ ] Ağ koparsa otomatik yeniden bağlanma

### Sprint 3 — Tasarım uygulaması
- [ ] Mica, NavigationView, Favoriler ızgarası, Şimdi Çalıyor çubuğu
- [ ] Açık/koyu tema, istasyon logoları (önbellekli)
- [ ] Kısayollar: Boşluk = çal/durdur, Ctrl+1..9 = favori, Ctrl+F = ara
- [ ] Erişilebilirlik + ui-ux-pro-max WinUI kontrol listesi
- [ ] Mini pencere (opsiyonel)

### Sprint 4 — İçerik
- [ ] Keşfet: Radio Browser API (`countrycode=TR`, arama, tür) → favorilere ekle/çıkar
- [ ] Şimdi çalan şarkı adı (ICY metadata)
- [ ] `stations.json`'u GitHub raw'dan çek (Apple uygulamasıyla ortak liste)

### Sprint 5 — Paketleme
- [ ] `dotnet publish` self-contained (WindowsAppSDKSelfContained), kullanıcı klasörüne kurulum, admin yok
- [ ] Windows ile başlat (opsiyonel)
- [ ] Güncelleme yolu (GitHub Release'ten yeni zip) + README

### Sonra — Apple (SwiftUI Multiplatform)
- [ ] A1 çalan MVP (AVPlayer, arka plan ses) · A2 kilit ekranı/AirPods + Mac menü çubuğu · A3 tasarım + widget · A4 Siri/Kestirmeler, iCloud favoriler
