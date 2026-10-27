---
name: native-app-ui
description: Native masaüstü/mobil uygulama UI/UX kuralları — WinUI 3 (.NET, Windows 11) ve SwiftUI (iOS/macOS). Ekran, bileşen, gezinme, tema, erişilebilirlik, medya oynatıcı arayüzü tasarlarken, yazarken veya gözden geçirirken kullan. Web/landing sayfası için değil.
---

# Native App UI

Platformun kendi tasarım dilini (Windows → Fluent 2, Apple → Human Interface Guidelines) izleyen,
sade ve tutarlı native arayüzler için kurallar. Esin kaynağı: ui-ux-pro-max (MIT) — oradaki
WinUI/SwiftUI ve UX kurallarından seçilip bu projeye uyarlandı; web'e özgü kısımlar alınmadı.

## Ne zaman
- Yeni ekran/pencere/bileşen tasarlarken veya XAML/SwiftUI view yazarken
- Gezinme, tema, ikon, boşluk, animasyon, klavye/erişilebilirlik kararlarında
- "Profesyonel görünmüyor" / "bir şey eksik" denildiğinde → önce `references/checklist.md`
- Saf iş mantığı, API, veri katmanı işlerinde kullanma.

## Temel ilke: platform önce
1. **Hazır kontrolü kullan, kendin çizme.** NavigationView, InfoBar, ContentDialog, ProgressRing /
   NavigationSplitView, List, Form, ProgressView. Özel kontrol ancak hazırı gerçekten yetmezse.
2. **Sistem tokenlarını kullan, sabit değer yazma.** Renk: tema kaynakları / semantik renkler
   (sabit hex yok). Yazı: platform tip rampası (Segoe UI Variable / SF Pro, Dynamic Type).
   Vurgu rengi: kullanıcının sistem vurgu rengi.
3. **Açık + koyu + yüksek kontrast** her ekranda çalışır. Tasarım koyu temada başlar, açıkta da test edilir.
4. **İkonlar:** Segoe Fluent Icons / SF Symbols. Emoji ikon yok. Sadece ikonlu her düğmenin erişilebilir adı ve tooltip'i var.
5. **Her şey klavyeyle yapılabilir** (Windows/macOS), VoiceOver/Narrator ile okunur.

## Öncelik sırası (çakışmada üstteki kazanır)
| # | Alan | Olmazsa olmaz |
|---|------|---------------|
| 1 | Erişilebilirlik | Kontrast ≥ 4.5:1 (metin), erişilebilir ad, klavye/odak görünür, VoiceOver/Narrator |
| 2 | Etkileşim | Tıklama hedefi ≥ 32px masaüstü / 44pt iOS; her eylemde ≤100 ms görsel geri bildirim; yükleniyor/hata durumu |
| 3 | Platform uyumu | Hazır kontrol, sistem malzemesi (Mica / materials), platform gezinme kalıbı |
| 4 | Düzen | 4/8 px ızgara; pencere küçülünce bozulmaz (adaptive); yatay kaydırma yok |
| 5 | Tipografi & renk | Tip rampası, semantik renk, en fazla 1 vurgu rengi |
| 6 | Hareket | 150–300 ms, anlam taşır; "hareketi azalt" ayarına uyar; çıkış girişten hızlı |
| 7 | Geri bildirim | Boş durum, yükleniyor, hata (ne oldu + ne yapmalı), başarı; hata mesajı yerinde |
| 8 | Gezinme | ≤ 5 ana bölüm; geri davranışı tahmin edilebilir; son konum hatırlanır |

## Akış
1. **Ekranı tanımla:** amaç (tek cümle), birincil eylem, durumlar (boş / yükleniyor / dolu / hata / çevrimdışı).
2. **Platform kalıbını seç:** `references/winui.md` veya `references/swiftui.md`.
3. **Alan kalıbı varsa uygula:** medya/oynatıcı → `references/player.md`.
4. **Yaz:** MVVM; view'da iş mantığı yok; tokenlar; erişilebilir adlar.
5. **Teslimden önce:** `references/checklist.md` maddelerini tek tek geç, eksikleri söyle.

## Kapsam dışı / yapma
- Web kalıpları (hero, CTA tekrarı, landing bölümleri), Google Fonts, CSS değişkenleri.
- Platformlar arası "aynı görünsün" diye tek tasarımı zorlamak: Windows Fluent gibi, Apple Apple gibi
  görünür; **ortak olan bilgi mimarisi ve davranıştır**, piksel değil.
- Kullanıcıya sormadan marka rengi/yazı tipi uydurmak.
