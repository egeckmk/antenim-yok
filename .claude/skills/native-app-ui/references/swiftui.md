# SwiftUI (iOS + macOS) kuralları

## Kabuk
- iOS: `TabView` (≤ 5 sekme) veya `NavigationStack`; macOS: `NavigationSplitView` (kenar çubuğu) + menü komutları (`.commands`).
- Gezinme: `NavigationStack` + `.navigationDestination(for:)`; kapatma `@Environment(\.dismiss)`. `NavigationView` yok.
- macOS ek yüzeyler: `MenuBarExtra`, `Settings { }` sahnesi, pencere boyutu `.defaultSize`.
- Ortak kod, platform farkı `#if os(...)` ile minimumda; ortak olan model + ViewModel.

## Stil
- Renk: semantik (`.primary`, `.secondary`, `Color.accentColor`, `.background`, `.tint`); sabit renk yok.
  Malzeme: `.regularMaterial` / `.thinMaterial` (Liquid Glass sistem bileşenlerinde kendiliğinden).
- Yazı: `.font(.body/.headline/.title…)` — Dynamic Type ile ölçeklenir; sabit punto yok.
- İkon: SF Symbols, `.symbolRenderingMode`, durum değişiminde `.contentTransition(.symbolEffect(.replace))`.
- Boşluk: varsayılan `.padding()` ve stack spacing; özel değerler 4/8'in katları, tek yerde sabit.
- Tekrarlayan stil → `ViewModifier` / `ButtonStyle`.

## Durum & mimari
- `@Observable` ViewModel (`@MainActor`), view'da `@State` sahiplik, alt view'a `@Bindable`; paylaşılan → `.environment(...)`.
- View'lar küçük ve "aptal": iş mantığı ViewModel/servis katmanında; servis protokolle enjekte.
- Async: `.task { }` (onAppear + Task yok); yükleniyor → `ProgressView`; boş → `ContentUnavailableView`.
- Listeler: `List` / `LazyVGrid`, kararlı `Identifiable` id (index değil).

## Erişilebilirlik
- Sadece ikonlu düğmelerde `.accessibilityLabel`; dekoratif görseller `.accessibilityHidden(true)`.
- Dynamic Type'ın en büyük boyunda düzen kırılmaz; `@Environment(\.accessibilityReduceMotion)` saygı.
- Dokunma hedefi ≥ 44×44 pt; macOS'ta klavye kısayolları `.keyboardShortcut`.
- `#Preview`: açık, koyu, büyük yazı, boş durum.
