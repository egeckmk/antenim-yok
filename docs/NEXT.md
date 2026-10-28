# Sıradaki görev (Claude Code için) — Apple: A1 çalan MVP

Windows uygulaması bitti (1.0.0, GitHub Release yayında). Şimdi **iPhone + Mac** uygulaması, Ege'nin Mac'inde.

Önce oku: `CLAUDE.md`, `docs/PLAN.md` ("Sonra — Apple"), `docs/WIREFRAME.md`, `.claude/skills/native-app-ui` (özellikle `references/swiftui.md`, `player.md`), `.claude/skills/versioning`.

1. `apple/` altında **SwiftUI Multiplatform** Xcode projesi (iOS + macOS). Bundle id `com.egeckmk.antenimyok`.
   `MARKETING_VERSION` 0.1.0; sürümler Windows'tan bağımsız (`mac-vX.Y.Z`, `apple/CHANGELOG.md`).
2. A1 kapsamı: favoriler (boş başlar, cihazda), Keşfet (Radio Browser, `countrycode=TR`), tıkla-çal / durdur, ses,
   `AVPlayer` (HLS + Icecast), arka planda çalma (iOS background audio), yayın açılmazsa sıradaki akış.
3. Davranış referansı Windows'taki `src/AntenimYok.Core` ve testleri (yedek akış, yeniden bağlanma, tür grupları,
   `.pls/.m3u`, ICY şarkı adı). Kodu taşıma, Swift'te yeniden yaz; testleri XCTest/Swift Testing ile yaz.
4. Commit mesajları İngilizce, **`Co-Authored-By` satırı yok**. Bitince `docs/PLAN.md`'de A1'i işaretle, bu dosyayı sil.
