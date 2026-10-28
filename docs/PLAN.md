# Antenim Yok — Sprint planı

> Kaynak: Ege'nin "Beyin" kasası. İlerleme burada işaretlenir.

## Sprintler
Her sprint ≈ 1 akşam / 2–3 saat. Her sprint sonunda çalışan bir exe + kısa test.

### Sprint 0 — Hazırlık & tasarım (kod yok)
- [x] İstasyon listesi (9): Alem FM, Best FM, Show Radyo, Power FM, Metro FM, Virgin Radio Türkiye, Power Türk, Radyo Fenomen, Kafa Radyo
- [x] Akış URL'leri bulundu → stations.json v1 (sonradan kaldırıldı) (9 istasyon, yedek akışlı; `unverified` olanlar Sprint 1'de denenecek; Power Türk, Fenomen, Kafa logosu yok)
- [x] Uygulamanın adı: **Antenim Yok** ✅ (repo: `antenim-yok`)
- [x] Ana pencere + mini pencere + tepsi menüsü wireframe'i (onay) → [WIREFRAME.md](WIREFRAME.md)
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
- [x] Mica, NavigationView (Favoriler / Keşfet / Ayarlar), TitleBar'da arama, Favoriler ızgarası (çalan kart vurgulu), Şimdi Çalıyor çubuğu
- [x] Açık/koyu tema (Ayarlar → Tema: Sistem/Açık/Koyu), istasyon logoları (önbellekli, `%LOCALAPPDATA%/AntenimYok/logos`)
- [x] Kısayollar: Boşluk = çal/durdur, Ctrl+1..9 = favori, Ctrl+F = ara, Ctrl+↑/↓ = ses, M = sessiz
- [ ] Erişilebilirlik + ui-ux-pro-max WinUI kontrol listesi — adlar/tooltip, başlık seviyeleri, klavye ✅; Narrator turu + Accessibility Insights FastPass yapılmadı
- [x] Mini pencere (her zaman üstte, önceki/durdur/sonraki + ses, konumu hatırlanır)
- [x] Tepsi menüsünde favoriler (çalan işaretli) — menü görüntüsü elle kontrol edilecek
- [x] Ayarlar: "kapatınca tepside çalmaya devam et", son açık bölüm hatırlanır

### Sprint 4 — İçerik
- [x] Keşfet: Radio Browser API (`countrycode=TR`, arama, tür) → favorilere ekle/çıkar (645 farklı radyo; aynı adlı kayıtlar birleştirilir)
- [x] Şimdi çalan şarkı adı (ICY metadata) — sadece ICY gönderen Icecast yayınlar (şu an Alem, Metro, Virgin); HLS'te yok. Uygulamada canlı görülmedi, elle kontrol edilecek
- [x] ~~`stations.json`'u GitHub/Gist'ten çek~~ — vazgeçildi: favoriler yerelde ve boş başlar, `data/stations.json` repodan kaldırıldı

### Sprint 5 — Paketleme
- [x] `dotnet publish` self-contained → Velopack `Setup.exe` (`scripts/publish.ps1`), `%LOCALAPPDATA%\Ege.AntenimYok`, admin yok;
      yayın çıktısındaki eksik `.pri` düzeltildi, kullanılmayan SDK parçaları atıldı (275 → 220 MB, kurulum 92 MB)
- [x] Windows ile başlat (Ayarlar; HKCU Run, `--background` → pencere açmadan tepside)
- [x] Otomatik güncelleme: Velopack + GitHub Releases (açılışta ve 6 saatte bir; "Yeniden başlat" bilgi çubuğu). Repo public olunca çalışır
- [x] README (ekran görüntüleri, kurulum, SSS), GPL-3.0, repo public, 1.0.0 GitHub Release (uygulama "Güncel" görüyor; ilk gerçek güncelleme 1.0.1 ile denenecek)

### Sonra — Apple (SwiftUI Multiplatform)
- [x] A1 çalan MVP (AVPlayer, arka plan ses)
- [x] A2 kilit ekranı/AirPods + Mac menü çubuğu
- [ ] A3 tasarım + widget · A4 Siri/Kestirmeler, iCloud favoriler

#### A2 alt sprintleri (geliştirici ajan yazar, test ajanı doğrular)
- [x] **A2.0 Şimdi Çalıyor + Mac kısayolları** (önceden yapıldı): Denetim Merkezi / medya tuşları / kilit ekranı kartı,
      sonraki/önceki favori, baş harfli yedek kapak; Boşluk, ⌘1…9, ⌘F, ⌘↑/↓, M, Oynatma menüsü
- [x] **A2.1 Mac menü çubuğu:** `MenuBarExtra` (Windows tepsi menüsü gibi): favoriler (çalan işaretli, tıkla = çal),
      Çal/Durdur, Pencereyi göster, Çıkış. Pencere kapanınca çalma sürer (Ayarlar: "Kapatınca menü çubuğunda çalmaya devam et",
      varsayılan açık); kapalıysa son pencere kapanınca uygulama çıkar
- [x] **A2.2 Mac mini pencere:** küçük, her zaman üstte, yeniden boyutlanmaz; logo + ad, ⏮ ⏹ ⏭ (komşu favori), ses,
      ⤢ ana pencereye dön; Şimdi Çalıyor çubuğunda ⧉ düğmesi; konumu hatırlanır (WIREFRAME "Mini pencere")
- [x] **A2.3 Mac oturum açılışında başlat:** Ayarlar'da anahtar (`SMAppService.mainApp`); açılışta pencere açmadan menü çubuğunda başlar
- [x] **A2.4 iPhone ses yolu:** kulaklık/AirPods çıkınca çalma durur (route change), telefon/kesinti sonrası devam;
      kilit ekranı kartında kontrol düğmeleri (simülatörde görünmedi — gerçek cihazda Ege dener)
- [x] **A2.5 Kapanış + 0.2.0:** iki platformda derleme + tüm testler yeşil, CHANGELOG, A2'yi işaretle; `MARKETING_VERSION` 0.2.0,
      `Release Apple 0.2.0` commit'i, yerel `mac-v0.2.0` tag'i, Mac `.app` zip'i (`apple/build/`, repoya girmez).
      **Push ve GitHub Release yok** — Ege test edip onaylayınca

#### A1 alt sprintleri (geliştirici ajan yazar, test ajanı doğrular)
- [x] **A1.1 İskelet:** `apple/project.yml` (xcodegen) → `AntenimYok.xcodeproj`; tek multiplatform hedef (iOS 18+ / macOS 15+),
      bundle id `com.egeckmk.antenimyok`, `MARKETING_VERSION` 0.1.0, iOS `UIBackgroundModes=audio`, macOS sandbox + ağ istemcisi;
      mantık yerel Swift paketi `apple/AntenimYokCore` (UI'sız, `swift test` ile test edilir); `apple/CHANGELOG.md`, `.gitignore`
- [x] **A1.2 Model + depolama:** `Station` (Windows `favorites.json` ile aynı JSON), `FavoritesStore` (boş başlar, Application Support,
      atomik yazma), `SettingsStore` (son istasyon, ses), `.pls/.m3u` çözümleme
- [x] **A1.3 Keşfet verisi:** `RadioBrowserClient` (`countrycode=TR`, arama, tür), tür grupları, aynı adlı kayıtları birleştirme, istasyon arama
- [x] **A1.4 Çalma motoru:** `RadioPlayer` (`AVPlayer` soyutlamasıyla test edilebilir): durumlar (bağlanıyor/çalıyor/hata), ~10 sn'de
      açılmazsa sıradaki akış, yeniden bağlanma (artan bekleme ≤5 dk, ağ gelince hemen, 15 sn takılma = kopma), iOS `AVAudioSession`
      arka plan, ICY şarkı adı
- [x] **A1.5 Arayüz:** Favoriler / Keşfet / Ayarlar (Mac: `NavigationSplitView`, iPhone: `TabView`), arama, tür süzgeci,
      favoriye ekle/çıkar, Şimdi Çalıyor çubuğu (çal/durdur, ses, şarkı adı), logolar, açık/koyu, VoiceOver adları — `native-app-ui`
- [x] **A1.6 Kapanış:** iki platformda derleme + tüm testler yeşil, gerçek istasyonla elle çalma denemesi (Mac), CHANGELOG 0.1.0,
      A1'i işaretle, `docs/NEXT.md` sil
