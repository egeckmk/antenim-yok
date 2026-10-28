# Uygulama simgesi (Icon Composer)

`apple/AntenimYok/AppIcon.icon` şu an bu klasördeki SVG katmanlarından elle kurulmuş **geçici** bir simgedir (derleme çalışsın diye).
Asıl simgeyi Icon Composer'da şöyle yap:

1. Xcode > Open Developer Tool > **Icon Composer**'ı aç, yeni bir belge oluştur (1024 tuval).
2. `background.svg`'yi arka plan katmanı, `foreground.svg`'yi ön plan katmanı olarak sürükle (ön plan üstte). Kenar boşluğu hazır: çizim 824 px güvenli alanın içinde.
3. Katmanı seçip **Glass / Translucency / Shadow** ayarlarını beğenine göre aç-kapat; **Dark** ve **Tinted** görünümlerini sağ üstten dene
   (koyu için `background-dark.svg` renklerini fill olarak kullanabilirsin). Önizlemeler: `preview-light.png`, `preview-dark.png`.
4. Dosyayı **`AppIcon.icon`** adıyla `apple/AntenimYok/AppIcon.icon` yoluna kaydet (eskisinin üstüne yaz).
5. `cd apple && xcodegen generate`, Xcode'da derle; hedef Ayarlar'da *App Icon* = `AppIcon` kalmalı. Simgeyi iPhone/Mac'te kontrol et.

Katmanlar özgündür (SF Symbols ya da başka marka kullanılmadı). Önizlemeyi yeniden üretmek için:
`swift render-preview.swift background.svg foreground.svg preview-light.png`
