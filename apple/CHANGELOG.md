# Değişiklik günlüğü — Apple (iPhone + Mac)

Apple uygulamasının önemli değişiklikleri (Windows: `CHANGELOG.md`). Tag'ler `mac-vX.Y.Z`.
Biçim [Keep a Changelog](https://keepachangelog.com/tr-TR/1.1.0/), sürümleme [Semantic Versioning](https://semver.org/lang/tr/)
(kurallar: `.claude/skills/versioning/SKILL.md`).

## [Yayınlanmadı]

### Eklendi
- Sistem "Şimdi Çalıyor": Mac'te Denetim Merkezi kartı ve medya tuşları, iPhone'da kilit ekranı ve AirPods; çal/durdur ve sonraki/önceki favori, şarkı adı, istasyon adı ve logo gösterilir.
- Mac'te Windows'taki klavye kısayolları: Boşluk = çal/durdur, ⌘1…9 = favoriler, ⌘F = ara, ⌘↑/↓ = ses, M (veya ⌥⌘↓) = sessiz;
  yeni "Oynatma" menüsü (ilk 9 favori adıyla) ve Ayarlar'da kısayol listesi.

### Düzeltildi
- Mac'te arama kutusuna boşluk veya "m" yazınca çalma durması / sessize alınması.

## [0.1.0] - 2026-10-28

İlk çalan sürüm (iPhone + Mac).

### Eklendi
- Favoriler: başta boş, yalnızca cihazda saklanır; karta dokununca çalar, tekrar dokununca durur.
- Keşfet: Türkiye'deki radyoları adına göre arama ve türe göre filtreleme (Pop, Rock, Türkü / Halk, Türk Sanat, Arabesk, Nostalji, Caz, Klasik, Elektronik, Haber / Konuşma, Dini); yıldızla favoriye ekleme/çıkarma.
- Şimdi Çalıyor çubuğu: çal/durdur, çalan şarkının adı (destekleyen istasyonlarda), Mac'te ses ve sessiz; iPhone'da dokununca genişler.
- Yayın açılmazsa istasyonun sıradaki akışı denenir; bağlantı kopunca artan beklemeyle (en çok ~5 dk) yeniden bağlanır, ağ gelince hemen dener.
- iPhone'da arka planda ve ekran kapalıyken çalma.
- Ayarlar: tema (Sistem / Açık / Koyu), şarkı adlarını gösterme.
