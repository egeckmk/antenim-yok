# Antenim Yok — Çalışma kuralları

Reklamsız radyo uygulaması (App Store / Store yok; public repo, GPL-3.0). Sahibi: Ege.

- Dil: Ege ile **Türkçe** konuş. Kod, tip/metot adları ve commit mesajları İngilizce; arayüz metinleri Türkçe.
- Commit mesajlarına `Co-Authored-By` (veya başka bir AI imza) satırı **ekleme**; Release'lerde katkıcı olarak görünmesin.
- Plan: `docs/PLAN.md`. Bir sprint maddesi bitince `- [x]` yap.
- Arayüz işi (XAML/SwiftUI, ekran, bileşen, tema, erişilebilirlik) yaparken **`native-app-ui` skill'ini kullan** (`.claude/skills/native-app-ui/`).
- Sürüm: SemVer, **platform başına bağımsız** (Windows: `Directory.Build.props`, tag `win-vX.Y.Z`, `CHANGELOG.md`;
  Apple: `MARKETING_VERSION`, tag `mac-vX.Y.Z`, `apple/CHANGELOG.md`). Sürüm çıkarırken, CHANGELOG yazarken ve kullanıcıya
  görünen her değişikliği commit'lerken **`versioning` skill'ini kullan** (`.claude/skills/versioning/`).

## Platformlar
| Platform | Teknoloji | Klasör |
|---|---|---|
| Windows 11 | .NET 10, WinUI 3 (Windows App SDK), C# | `src/` |
| iPhone + Mac | SwiftUI Multiplatform | `apple/` (sonra) |

## Windows mimarisi
```
AntenimYok.slnx
src/AntenimYok.Core/     # net10.0 class library — WinUI referansı YOK
                         # Station modeli, FavoritesStore, playlist (.pls/.m3u) çözümleme, RadioPlayer (yedek akış, yeniden bağlanma),
                         # RadioBrowserClient + Genre (Keşfet), IcyMetadataReader/SongTitleMonitor, SettingsStore
src/AntenimYok.App/      # WinUI 3 — Views, ViewModels (CommunityToolkit.Mvvm), MediaPlayer, SMTC, tepsi (H.NotifyIcon.WinUI)
tests/AntenimYok.Tests/  # xUnit — Core + ViewModel testleri
```
- MVVM: `[ObservableProperty]`, `[RelayCommand]` (async Task), DI: Microsoft.Extensions.DependencyInjection, `ILogger<T>`.
- Çalma: `Windows.Media.Playback.MediaPlayer`; HLS için `AdaptiveMediaSource`, diğerleri `MediaSource.CreateFromUri`.
  İstasyonun `streams` listesi öncelik sırasıdır: açılmazsa (timeout ~10 sn) sıradakine geç.
- Medya tuşları / Windows ses penceresi: `SystemMediaTransportControls`, ana pencereye bağlı
  (`ISystemMediaTransportControlsInterop.GetForWindow`; Hızlı Ayarlar'daki karta tıklayınca pencere açılsın diye).
- Dağıtım: **paketsiz + self-contained** (`WindowsPackageType=None`, `WindowsAppSDKSelfContained=true`, `SelfContained=true`),
  **Velopack** ile `Setup.exe` (packId `Ege.AntenimYok` → `%LOCALAPPDATA%\Ege.AntenimYok`, admin yok) ve GitHub Releases'ten
  otomatik güncelleme (`UpdateService`). Exe: `AntenimYok.exe`. Başlat menüsü kısayolunu Velopack değil uygulama oluşturur
  (AUMID `Ege.AntenimYok`); kaldırmada Velopack kancası siler. `VelopackApp.Run()` `Main`'in ilk satırı kalmalı.
- Yayın çıktısı uygulamanın `.pri` dosyasını kendiliğinden kopyalamaz → csproj'daki `PublishAppResourceIndex` hedefi; silme.

## İstasyonlar ve veri
- Repoda istasyon listesi **yok** (Ege kaldırdı; Gist de denendi, istenmedi). İstasyonlar Keşfet'ten (Radio Browser, TR) gelir.
- Favoriler boş başlar, yalnızca yerelde tutulur; her favori tam kopya (`Station`: akışlar, logo, `logoOnDarkOnly`, `radioBrowserUuid`).
- Kullanıcı verisi `%LOCALAPPDATA%\AntenimYok\`: `settings.json`, `favorites.json`, `logos\`, `crash.log`. Dosyalar `AtomicFile` ile yazılır.

## Komutlar (Windows)
- Derle: `dotnet build AntenimYok.slnx -c Debug -p:Platform=x64`
- Test: `dotnet test tests/AntenimYok.Tests`
- Yayın (Setup.exe): `.\scripts\publish.ps1` · bu PC'ye kur: `-Install` · GitHub Release: `-Upload` (`$env:GITHUB_TOKEN` gerekir;
  token'ı Ege verir, repoya/komut geçmişine yazma). `src/AntenimYok.App` klasöründe VS'nin eski `.slnx`'i olabilir: `dotnet publish`'e
  her zaman `.csproj` yolunu ver.

## Kurallar
- Değişiklikten sonra derle + testleri çalıştır; derlenmeyen kod commit'lenmez.
- Sabit renk/punto yok (ThemeResource, tip rampası). Sadece ikonlu düğmede `AutomationProperties.Name` + tooltip.
- Gizli bilgi (token, şifre) repoya girmez.
