# Antenim Yok — Sprint planı

> Kaynak: Ege'nin "Beyin" kasası. İlerleme burada işaretlenir.

## Sprintler
Her sprint ≈ 1 akşam / 2–3 saat. Her sprint sonunda çalışan bir exe + kısa test.

### Sprint 0 — Hazırlık & tasarım (kod yok)
- [x] İstasyon listesi (9): Alem FM, Best FM, Show Radyo, Power FM, Metro FM, Virgin Radio Türkiye, Power Türk, Radyo Fenomen, Kafa Radyo
- [x] Akış URL'leri bulundu → [stations.json](stations.json) v1 (9 istasyon, yedek akışlı; `unverified` olanlar Sprint 1'de denenecek; Power Türk, Fenomen, Kafa logosu yok)
- [x] Uygulamanın adı: **Antenim Yok** ✅ (repo: `antenim-yok`)
- [ ] Ana pencere + mini pencere + tepsi menüsü wireframe'i (onay)
- [x] GitHub'da kişisel repo `egeckmk/antenim-yok`, solution iskeleti (App net10 paketsiz/self-contained x64 + Core + Tests)
- [x] `native-app-ui` skill'ini repoya `.claude/skills/` altına kopyala

### Sprint 1 — Çalan MVP
- [x] `stations.json` uygulamaya gömülü; istasyon listesi
- [x] Tıkla → çal; çal/durdur; ses ayarı
- [x] Akış yedeği: ilki çalmazsa `streams` listesindeki sonrakine geç
- [x] Durumlar: bağlanıyor / çalıyor / hata ("yayına ulaşılamadı")
- [x] `.pls`/`.m3u` → gerçek URL çözümleme (+ test)
- **Bitti:** 8/9 istasyon açılıyor (2026-10-27, UI Automation ile). Best FM bu ağda engelli
  (TLS denetimi, 403) — başka ağda denenecek. `unverified` akışların hepsi çalıştı, işaret kaldırıldı.

### Sprint 2 — Windows entegrasyonu
- [x] SMTC: klavye medya tuşları, Windows ses penceresinde istasyon adı + logo (oynat/duraklat = çal/durdur, ileri/geri = sonraki/önceki istasyon)
- [x] Tepsi simgesi; kapatınca tepside çalmaya devam (gerçek çıkış: tepsi menüsü → Çıkış)
- [x] Tek örnek (ikinci açılışta mevcut pencere öne gelir)
- [x] Son istasyon + ses seviyesi hatırlanır (`%LOCALAPPDATA%\AntenimYok\settings.json`)
- [x] Ağ koparsa otomatik yeniden bağlanma (artan bekleme ~5 dk; ağ geri gelince hemen dener; 15 sn takılan akış kopmuş sayılır)
- **Not:** Uygulama ikonu geçici (koyu kare + Fluent anten glifi, `Assets/AppIcon.ico`). Yeniden bağlanma birim testli; gerçek ağ kopması elle denenecek.

### Sprint 3 — Tasarım uygulaması
- [ ] Mica, NavigationView, Favoriler ızgarası, Şimdi Çalıyor çubuğu
- [ ] Açık/koyu tema, istasyon logoları (önbellekli) — logolar ✅ (pencere + medya penceresi, `%LOCALAPPDATA%/AntenimYok/logos`); açık tema henüz denenmedi
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
