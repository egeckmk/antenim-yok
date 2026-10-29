# App Store içeriği (Türkçe)

- `tr/` — mağaza metinleri (`check-store-text.sh` karakter sınırlarını denetler) ve `review-notes.md` (inceleme notu).
- `screenshots/` — ekran görüntüleri (repoya girmez; `.gitignore`). Gerçek Radio Browser istasyonlarıyla DEBUG demo modu üretir.

## iPhone (6.9", 1320 × 2868)
`apple/scripts/screenshots.sh iphone` — "iPhone 18 Pro Max" simülatöründe açık/koyu × Favoriler/Keşfet, saat 9:41; ağ gerekir (~2 dk).

## Mac
App Store'un kabul ettiği boyutlar: 2880×1800, 2560×1600, 1440×900, 1280×800. Demo modu pencereyi 1440×900 pt yapar (Retina'da 2880×1800 px).
1. Retina ekranlı Mac'te `apple/scripts/screenshots.sh mac-manual` çalıştır (Terminal'e Ekran Kaydı izni gerekmez).
2. Uygulama açılır; ~15 sn bekle (radyolar yüklenir, bir radyo çalar).
3. ⇧⌘4 bas, Boşluk'a bas, **⌥ basılı tutarak** uygulama penceresine tıkla (gölgesiz görüntü). Masaüstüne düşen dosyayı
   `apple/AppStore/screenshots/mac/<favorites|discover>-<light|dark>.png` olarak taşı.
4. Terminalde Return → sıradaki tema/ekran. Dört görüntü: favorites-light, discover-light, favorites-dark, discover-dark.
5. Boyutu kontrol et: `sips -g pixelWidth -g pixelHeight <dosya>` → 2880 × 1800 olmalı (değilse pencere küçülmüş; yeniden dene).

Terminal'e Ekran Kaydı izni verilmişse `apple/scripts/screenshots.sh mac` aynısını kendisi yapar (`screencapture -l`).

## App Store Connect'e girerken
`tr/metadata.md` tabloyu, `tr/*.txt` metinleri, `tr/review-notes.md` inceleme notunu içerir.

## "Invalid Signature" (Organizer / Transporter)
Belirti: yükleme `Invalid Signature. Code failed to satisfy specified code requirement(s)` ile reddedilir.
Neden: Xcode, bulutta yönetilen "Apple Distribution" sertifikasıyla imzalarken kod gereksinimine (designated requirement)
sertifika adını yazar; "Ege Çakmak" içindeki `Ç` bu adımda ayrışık Unicode'a (C + U+0327) dönüşür ve gerçek sertifika adıyla
(`Ç` = U+00C7) eşleşmez. `codesign --verify --deep --strict <app>` "does not satisfy its designated Requirement" der.
Organizer da aynı imzalama hattını kullandığı için aynı hatayı verir.
Çözüm: dağıtım sertifikasını yerel özel anahtarla kur, `archive.sh` onu SHA-1 ile seçer (adla değil):
1. Keychain Access → Certificate Assistant → *Request a Certificate From a Certificate Authority* → "Saved to disk".
2. developer.apple.com → Certificates → **+ → Apple Distribution** (CSR'yi yükle), `.cer`'i indir ve çift tıkla (login keychain).
   Mac için aynı yolla **Mac Installer Distribution** (CSR ile) sertifikası da kur.
3. `security find-identity -v -p codesigning` çıktısında "Apple Distribution: …" görünmeli (anahtarlı).
4. `apple/scripts/archive.sh all`: script yerel kimliği bulur, export'tan sonra uygulamayı `codesign --verify` ile denetler
   ve imza bozuksa hata verir. Çıkan `.ipa` / `.pkg` dosyalarını **Transporter** ile yükle (Organizer ile değil).
