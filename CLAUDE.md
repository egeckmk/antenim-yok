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
| Ortak | İstasyon listesi | `data/stations.json` |

## Windows mimarisi
```
AntenimYok.slnx
src/AntenimYok.Core/     # net10.0 class library — WinUI referansı YOK
                         # Station modeli, StationRepository (stations.json), playlist (.pls/.m3u) çözümleme,
                         # RadioBrowserClient, IcyMetadataReader, ayarlar
src/AntenimYok.App/      # WinUI 3 — Views, ViewModels (CommunityToolkit.Mvvm), MediaPlayer, SMTC, tepsi (H.NotifyIcon.WinUI)
tests/AntenimYok.Tests/  # xUnit — Core + ViewModel testleri
```
- MVVM: `[ObservableProperty]`, `[RelayCommand]` (async Task), DI: Microsoft.Extensions.DependencyInjection, `ILogger<T>`.
- Çalma: `Windows.Media.Playback.MediaPlayer`; HLS için `AdaptiveMediaSource`, diğerleri `MediaSource.CreateFromUri`.
  İstasyonun `streams` listesi öncelik sırasıdır: açılmazsa (timeout ~10 sn) sıradakine geç.
- Medya tuşları / Windows ses penceresi: `SystemMediaTransportControls` (MediaPlayer.SystemMediaTransportControls).
- Dağıtım: **paketsiz + self-contained** (`WindowsPackageType=None`, `WindowsAppSDKSelfContained=true`, `SelfContained=true`).
  Admin gerektirmeyen, kurulumsuz klasör hedefleniyor.

## stations.json
- `streams[]`: `url`, `type` (`hls` | `icecast`), `codec`, `bitrate`, `unverified` (denenmemiş tahmin; çalışmazsa kaldır veya düzelt).
- `logo` null olabilir → baş harfler. `logoOnDarkOnly: true` → açık temada logonun arkasına koyu zemin.
- `radioBrowserUuid`: Radio Browser'dan güncel URL çekmek için (`https://all.api.radio-browser.info/json/stations/byuuid/<uuid>`).
- Şema değişirse Apple tarafını da düşün; alan adlarını keyfi değiştirme.
- Uygulamaya gömülü, internetten çekilmez (Gist denendi, Ege istemedi). **Favori değildir**: favoriler boş başlar,
  Keşfet'ten eklenir. Katalogdaki bir istasyon Keşfet'te seçilince Radio Browser kaydı yerine buradaki doğrulanmış akışlar/logo kullanılır.
- Kullanıcı verisi yalnızca yerelde, `%LOCALAPPDATA%\AntenimYok\`: `settings.json`, `favorites.json`, `logos\`, `crash.log`.

## Komutlar (Windows)
- Derle: `dotnet build AntenimYok.slnx -c Debug -p:Platform=x64`
- Test: `dotnet test tests/AntenimYok.Tests`
- Yayın: `dotnet publish src/AntenimYok.App -c Release -r win-x64 -p:Platform=x64`

## Kurallar
- Değişiklikten sonra derle + testleri çalıştır; derlenmeyen kod commit'lenmez.
- Sabit renk/punto yok (ThemeResource, tip rampası). Sadece ikonlu düğmede `AutomationProperties.Name` + tooltip.
- Gizli bilgi (token, şifre) repoya girmez.
