# Antenim Yok — Çalışma kuralları

Reklamsız, **sadece kişisel kullanım** için radyo uygulaması (App Store / Store yok). Sahibi: Ege.

- Dil: Ege ile **Türkçe** konuş. Kod, tip/metot adları ve commit mesajları İngilizce; arayüz metinleri Türkçe.
- Plan: `docs/PLAN.md`. Bir sprint maddesi bitince `- [x]` yap.
- Arayüz işi (XAML/SwiftUI, ekran, bileşen, tema, erişilebilirlik) yaparken **`native-app-ui` skill'ini kullan** (`.claude/skills/native-app-ui/`).

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
- Dağıtım: **paketsiz + self-contained** (`WindowsPackageType=None`, `WindowsAppSDKSelfContained=true`, `SelfContained=true`).
  Admin gerektirmeyen, kurulumsuz klasör hedefleniyor.

## İstasyonlar ve veri
- Repoda istasyon listesi **yok** (Ege kaldırdı; Gist de denendi, istenmedi). İstasyonlar Keşfet'ten (Radio Browser, TR) gelir.
- Favoriler boş başlar, yalnızca yerelde tutulur; her favori tam kopya (`Station`: akışlar, logo, `logoOnDarkOnly`, `radioBrowserUuid`).
- Kullanıcı verisi `%LOCALAPPDATA%\AntenimYok\`: `settings.json`, `favorites.json`, `logos\`, `crash.log`. Dosyalar `AtomicFile` ile yazılır.

## Komutlar (Windows)
- Derle: `dotnet build AntenimYok.slnx -c Debug -p:Platform=x64`
- Test: `dotnet test tests/AntenimYok.Tests`
- Yayın: `dotnet publish src/AntenimYok.App -c Release -r win-x64 -p:Platform=x64`

## Kurallar
- Değişiklikten sonra derle + testleri çalıştır; derlenmeyen kod commit'lenmez.
- Sabit renk/punto yok (ThemeResource, tip rampası). Sadece ikonlu düğmede `AutomationProperties.Name` + tooltip.
- Gizli bilgi (token, şifre) repoya girmez.
