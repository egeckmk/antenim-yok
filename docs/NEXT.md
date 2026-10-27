# Sıradaki görev (Claude Code için)

Sprint 0'ın kalanını yap, sonra Sprint 1'e geç (`docs/PLAN.md`).

1. `src/AntenimYok.App` Visual Studio 2026 şablonuyla oluşturuldu (net8.0, paketli/MSIX, x86/x64/ARM64). Şunları yap:
   - `TargetFramework` → `net10.0-windows10.0.19041.0`
   - Paketsiz: `WindowsPackageType=None`; MSIX ayarlarını (`EnableMsixTooling`, `HasPackageAndPublishMenu`, Msix ProjectCapability, `Package.appxmanifest`) kaldır
   - Self-contained: `SelfContained=true`, `WindowsAppSDKSelfContained=true`
   - Sadece x64: `Platforms=x64`, `RuntimeIdentifiers=win-x64` (pubxml'leri buna göre düzenle)
   - `PublishTrimmed` kapat (WinUI ile güvenli değil)
2. Kökte `AntenimYok.slnx` oluştur. `src/AntenimYok.App` içindeki eski `.sln`/`.slnx` dosyasını sil.
3. `src/AntenimYok.Core` (net10.0 class library, WinUI referansı yok) ve `tests/AntenimYok.Tests` (xUnit, Core'a referans) ekle.
4. `dotnet build AntenimYok.slnx -c Debug -p:Platform=x64` ve `dotnet test` çalıştır, uygulamayı aç (boş pencere).
5. `docs/PLAN.md`'de biten maddeleri işaretle, commit'le, push'la.
6. Sprint 1'e geç.

Bu dosyayı iş bitince sil.
