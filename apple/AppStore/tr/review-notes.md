# App Review notları (App Store Connect → Uygulama İncelemesi Bilgileri → Notlar)

Giriş / hesap gerekmez; demo hesabı yoktur.

**Uygulama ne yapar:** Türkiye'deki internet radyolarını reklamsız (uygulamada reklam yok) bir arayüzle çalan bir oynatıcıdır; radyoların kendi yayın içeriğine karışmaz (iPhone + Mac, tek kayıt).

**Radyo listesi ve içerik (Guideline 5.2.3):** Uygulama kendi içeriğini barındırmaz ve radyo yayını dağıtmaz. İstasyon listesi,
topluluk tarafından işletilen açık dizin Radio Browser'dan (https://www.radio-browser.info, ücretsiz genel API) alınır; ses
yayınları radyo kuruluşlarının kendi herkese açık sunucularından doğrudan oynatılır. Yayınlar, istasyonların internette kendi
yayımladığı ücretsiz yayınlardır; indirme, kaydetme ya da şifre/DRM kırma yoktur. Uygulama istasyon logolarını yalnızca
sunucunun bildirdiği logo adresinden gösterir.

**Test için:** Açılışta "Favoriler" boştur (cihazda tutulur). "Keşfet" sekmesinden herhangi bir radyoya dokunun, çalar; yıldız ile
favoriye ekleyin. Kilit ekranında/Denetim Merkezi'nde Şimdi Çalıyor kartı çıkar. Mac'te menü çubuğu simgesi ve mini oynatıcı vardır.
Bazı radyolar zaman zaman yanıt vermeyebilir (sunucuları bizim değil); başka bir radyo deneyin.

**Arka planda ses (iOS):** `UIBackgroundModes = audio`; yalnızca kullanıcı bir radyoyu çalarken ses çalar, başka amaçla kullanılmaz.

**Ağ güvenliği (ATS):** `NSAllowsArbitraryLoads` açıktır; çünkü birçok yerel radyo yayını, çalma listesi (.pls/.m3u), şarkı adı
(ICY) akışı ve logosu yalnızca düz http üzerinden sunulur ve bu adresler önceden bilinemez (alan adı istisnası listelenemez).
`NSAllowsArbitraryLoadsForMedia` tek başına yetmez: çalma listesi ve logolar URLSession ile alınır ve ATS (-1022) ile engellenir
(denendi). Uygulama yalnızca kullanıcının seçtiği radyonun adreslerine bağlanır; kullanıcı verisi göndermez.

**Veri toplama:** Yok (App Privacy: "Veri Toplanmıyor"). Üçüncü taraf SDK, analiz, reklam yok. Şifreleme: yalnızca sistemin
standart HTTPS'i (`ITSAppUsesNonExemptEncryption = false`).

**Açık kaynak:** GPL-3.0, App Store ek izniyle. Kaynak: https://github.com/egeckmk/antenim-yok

**Mac:** App Sandbox (yalnızca ağ istemcisi), Hardened Runtime. "Oturum açılınca başlat" ayarı `SMAppService` kullanır.
