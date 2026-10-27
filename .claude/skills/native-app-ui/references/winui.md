# WinUI 3 (Windows App SDK, .NET) kuralları

## Kabuk
- Pencere: `Window.SystemBackdrop = MicaBackdrop` (ana pencere). Geçici yüzeyler (flyout, menü) Acrylic. Ana pencerede Acrylic yok.
- Başlık çubuğu: `ExtendsContentIntoTitleBar = true` + `SetTitleBar(AppTitleBar)`; başlık yüksekliği/düğmeleri elle çizme.
- Gezinme: `NavigationView` (Left / LeftCompact; dar pencerede otomatik kapanır) + `Frame.Navigate(typeof(Page), param)`.
  Parametre tipli (`OnNavigatedTo`'da cast). `BackRequested` işlenir. Ayarlar = NavigationView'in yerleşik Settings öğesi.
- Uyarlanabilir düzen: `VisualStateManager` + `AdaptiveTrigger MinWindowWidth` (ör. 640 / 1008).
- Pencere boyutu/konumu: `AppWindow` ile kaydet ve geri yükle. İkincil pencere = `new Window().Activate()`.
- Tek örnek: `AppInstance.FindOrRegisterForKey("main")`; değilse `RedirectActivationToAsync` + çık.

## Stil
- Renk: yalnızca `{ThemeResource ...}` (ör. `TextFillColorPrimaryBrush`, `CardBackgroundFillColorDefaultBrush`,
  `AccentFillColorDefaultBrush`). Sabit hex yok → yüksek kontrast da bedavaya gelir.
- Küçük değişiklik = lightweight styling (kontrolün resource anahtarını ezmek); tam `ControlTemplate` kopyalama son çare.
- Ortak stiller `App.xaml` → `MergedDictionaries`.
- Tip rampası: `CaptionTextBlockStyle`, `BodyTextBlockStyle`, `BodyStrongTextBlockStyle`, `SubtitleTextBlockStyle`,
  `TitleTextBlockStyle`, `DisplayTextBlockStyle`. Kendi FontSize'ını yazma.
- Köşe: `ControlCornerRadius` (4) / `OverlayCornerRadius` (8). Kart: 8 px köşe, `CardStrokeColorDefaultBrush` kenar.
- Boşluk: 4'ün katları; sayfa kenarı 24–36, kartlar arası 8–12, bölüm arası 24–32.
- İkon: `FontIcon` + `SymbolThemeFontFamily` (Segoe Fluent Icons) veya `SymbolIcon`.

## Kontroller
- Durum mesajı → `InfoBar`; onay/giriş → `ContentDialog`; yükleniyor → `ProgressRing`/`ProgressBar`;
  ilk kullanım ipucu → `TeachingTip`; sayı → `NumberBox`; ayar grubu → `Expander` / SettingsCard.
- Liste/ızgara: `GridView`/`ListView`, özel düzen gerekirse `ItemsRepeater` + `UniformGridLayout`. Büyük liste → sanallaştırma.

## Bağlama & mimari
- `x:Bind` (derlenmiş), `Mode=OneWay/TwoWay` açıkça. `{Binding}` yalnızca zorunluysa.
  DataTemplate'te `x:DataType`. Basit dönüşüm → x:Bind fonksiyonu (converter yerine).
- Gizli paneller `x:Load`, ikincil içerik `x:Phase`.
- MVVM: CommunityToolkit.Mvvm — `[ObservableProperty]`, `[RelayCommand]` (async Task, `async void` yok).
  Listeler `ObservableCollection<T>`. DI: `Microsoft.Extensions.DependencyInjection` + `ILogger<T>`.
- İş mantığı WinUI referansı olmayan ayrı kütüphanede (Core). WinRT API'leri arayüz arkasında (test edilebilirlik).
- UI iş parçacığı: `DispatcherQueue.TryEnqueue`. IO = async/await; CPU işi `Task.Run`.

## Erişilebilirlik & klavye
- Her etkileşimli öğede `AutomationProperties.Name` (özellikle sadece ikonlu düğmeler) + `ToolTipService.ToolTip`.
- Kısayollar `KeyboardAccelerator` ile (KeyDown yakalama yok); menü öğelerinde görünür.
- Bölüm başlıklarında `AutomationProperties.HeadingLevel`. Sekme sırası mantıklı; odak görseli kaldırılmaz.
- Doğrulama: Accessibility Insights for Windows FastPass + Narrator ile bir tur.

## Paketleme (kişisel kullanım)
- Paketsiz: `<WindowsPackageType>None</WindowsPackageType>`, `<WindowsAppSDKSelfContained>true</WindowsAppSDKSelfContained>`,
  `<SelfContained>true</SelfContained>`. Paketsiz uygulamada bazı API'ler (ör. bildirim aktivasyonu) ek kayıt ister — kullanmadan önce kontrol et.
