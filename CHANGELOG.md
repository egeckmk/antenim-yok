# Değişiklik günlüğü

Bu dosyadaki tüm önemli değişiklikler burada tutulur.
Biçim [Keep a Changelog](https://keepachangelog.com/tr-TR/1.1.0/), sürümleme [Semantic Versioning](https://semver.org/lang/tr/)
(kurallar: `.claude/skills/versioning/SKILL.md`).

## [Yayınlanmadı]

## [1.0.0] - 2026-10-27

İlk kurulabilir sürüm.

### Eklendi
- Kurulum dosyası (`Setup.exe`): yönetici izni istemez, "Uygulamalar"dan kaldırılabilir; favoriler ve ayarlar kaldırmada silinmez.
- Otomatik güncelleme: yeni sürüm arka planda iner, "Yeniden başlat" ile ya da bir sonraki açılışta yüklenir. Ayarlar → Hakkında'da "Güncellemeleri denetle".
- "Windows açılınca başlat" ayarı: oturum açınca pencere açmadan tepside başlar.

### Değişti
- Uygulama dosyası artık `AntenimYok.exe`; kurulum boyutu küçüldü.

### Düzeltildi
- Yayın (paketlenmiş) sürümünün açılır açılmaz kapanması.

## [0.4.0] - 2026-10-27

### Eklendi
- Keşfet: Türkiye'deki radyoları adına göre arama ve türe göre filtreleme (Pop, Rock, Türkü/Halk, Türk Sanat, Arabesk, Nostalji, Caz, Klasik, Elektronik, Haber/Konuşma, Dini).
- Keşfet'te yıldızla favorilere ekleme/çıkarma; Favoriler'de sağ tıkla "Favorilerden çıkar".
- Çalan şarkının adı (destekleyen istasyonlarda): alt çubukta, mini pencerede, tepsi ipucunda ve Windows medya penceresinde. Ayarlar'dan kapatılabilir.
- "Henüz favori yok" ekranı ve "Keşfet'e git" düğmesi.
- Ayarlar → Hakkında'da sürüm numarası.

### Değişti
- Favoriler boş başlar ve yalnızca bu bilgisayarda tutulur; hazır istasyon listesi kaldırıldı.

### Düzeltildi
- Favori ve ayar kaydının arada bir sessizce kaybolması.

## [0.3.1] - 2026-10-27

### Düzeltildi
- Hızlı Ayarlar'daki medya kartına tıklayınca uygulama penceresi açılmıyordu (tepsideyken de açılır).
- Bir şey çaldıktan sonra uygulamadan çıkarken çökme.

### Eklendi
- Başlat menüsünde "Antenim Yok" kısayolu.

## [0.3.0] - 2026-10-27

### Eklendi
- Yeni ana pencere: Favoriler / Keşfet / Ayarlar menüsü, başlık çubuğunda istasyon arama, çalan istasyonun kartı vurgulu.
- Açık / koyu / sistem teması seçimi.
- Klavye kısayolları: Boşluk, Ctrl+1…9, Ctrl+F, Ctrl+↑/↓, M.
- Her zaman üstte duran mini oynatıcı.
- Tepsi menüsünde favoriler; "kapatınca tepside çalmaya devam et" ayarı.
- İstasyon logoları (pencerede ve Windows medya penceresinde).

## [0.2.0] - 2026-10-27

### Eklendi
- Klavye medya tuşları ve Windows medya penceresinde istasyon adı.
- Tepsi simgesi; pencereyi kapatınca tepside çalmaya devam.
- Uygulama tek kopya çalışır; ikinci açılış mevcut pencereyi öne getirir.
- Son istasyon ve ses seviyesi hatırlanır.
- Bağlantı koparsa otomatik yeniden bağlanma.

## [0.1.0] - 2026-10-27

### Eklendi
- İlk çalan sürüm: istasyon listesi, tıkla-çal, durdur, ses ayarı.
- Bir yayın açılmazsa sıradaki yedek yayına geçiş.
- Bağlanıyor / çalıyor / "yayına ulaşılamadı" durumları.
- `.pls` / `.m3u` çalma listelerini çözme.

[Yayınlanmadı]: https://github.com/egeckmk/antenim-yok/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/egeckmk/antenim-yok/compare/v0.4.0...v1.0.0
[0.4.0]: https://github.com/egeckmk/antenim-yok/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/egeckmk/antenim-yok/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/egeckmk/antenim-yok/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/egeckmk/antenim-yok/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/egeckmk/antenim-yok/releases/tag/v0.1.0
