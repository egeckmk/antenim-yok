# Antenim Yok — Wireframe (onaylandı 2026-10-27)

Kaba yerleşim; renk/punto yok. Uygulama (Sprint 3) bu iskeleti izler, ayrıntıları `native-app-ui` skill'i belirler.

## Ana pencere — Favoriler + Keşfet
```
┌────────────┬──────────────────────────────────────────┐
│ ★ Favoriler│ Favoriler                       [Ara   ] │
│   Keşfet   │ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐       │
│            │ │logo│ │logo│ │logo│ │logo│ │logo│       │
│            │ └────┘ └────┘ └────┘ └────┘ └────┘       │
│            │  Alem   Best   Show   Power  Metro       │
│ ⚙ Ayarlar  │                                          │
├────────────┴──────────────────────────────────────────┤
│ [logo] Kafa Radyo             ⏹   🔊 ────●────   ⧉    │
│        Çalıyor · AAC+ 64                              │
└───────────────────────────────────────────────────────┘
```
- Sol menü: `NavigationView` (dar pencerede kapanır). Bölümler: **Favoriler** (varsayılan), **Keşfet**, **Ayarlar** (altta).
- Favoriler: başta boş (boş durum + "Keşfet'e git"); ekle/çıkar Keşfet'ten.
- Keşfet: Radio Browser araması (Sprint 4). O zamana kadar boş durum.
- Alt çubuk (Şimdi Çalıyor) her bölümde görünür. `⧉` = mini pencereye geç.

## Mini pencere
```
┌──────────────────────────────┐
│ [logo] Kafa Radyo   ⏮ ⏹ ⏭  │
│        🔊 ────●────      ⤢   │
└──────────────────────────────┘
```
- Küçük, her zaman üstte (`AppWindow` + `OverlappedPresenter.IsAlwaysOnTop`), yeniden boyutlanmaz.
- ⏮ ⏭ = önceki/sonraki favori, `⤢` = ana pencereye dön. Konumu hatırlanır.

## Tepsi menüsü (sağ tık)
```
  ● Kafa Radyo      ← çalan işaretli
    Alem FM
    Best FM
    …
  ────────────
  Durdur / Çal
  Göster
  ────────────
  Çıkış
```
- Sol tık = pencereyi göster. Favoriye tıklamak = o istasyonu çal.
