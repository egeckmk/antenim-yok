---
name: versioning
description: Antenim Yok'un semantik sürümleme (SemVer) kuralları — sürüm numarasının tek kaynağı, hangi değişikliğin MAJOR/MINOR/PATCH olduğu, CHANGELOG.md, git tag ve sürüm çıkarma adımları. Sürüm numarasına dokunurken, sürüm/release çıkarırken, CHANGELOG yazarken, kullanıcıya görünen bir özellik veya düzeltme commit'lerken kullan.
---

# Sürümleme (SemVer)

Uygulama [Semantic Versioning 2.0.0](https://semver.org/lang/tr/) kullanır: `MAJOR.MINOR.PATCH`.
Kütüphane değil, kişisel bir uygulama olduğu için "uyumluluk" = **Ege'nin cihazındaki veri ve alışkanlıkları**.

## Tek kaynak
- Sürüm **yalnızca** kökteki `Directory.Build.props` → `<Version>` içinde yazar. Başka yere sürüm yazma
  (csproj, kod, XAML). Assembly/File/Informational sürümler oradan türetilir.
- Uygulama sürümü `AssemblyInformationalVersionAttribute`'tan okur (Ayarlar → Hakkında: `Sürüm 0.4.0 (abc1234)`;
  parantezdeki, SDK'nın eklediği commit kısaltmasıdır).
- `app.manifest` içindeki `assemblyIdentity version` paketsiz uygulamada işlevsizdir; dokunma.
- Apple tarafı gelince aynı numara `MARKETING_VERSION` olur; iki platform aynı sürümü taşır.

## Hangi parça artar
| Değişiklik | Artış | Örnek |
|---|---|---|
| Kullanıcı verisi/ayarları eski sürümle uyumsuz (dosya biçimi, kayıp), ya da büyük yeniden tasarım | **MAJOR** | `favorites.json` biçimi değişti ve eskisi okunamıyor |
| Yeni özellik, yeni ekran/ayar, davranış değişikliği (geriye uyumlu) | **MINOR** | Keşfet, şarkı adı, mini pencere |
| Hata düzeltmesi, performans, metin/görsel düzeltme | **PATCH** | kapanırken çökme, logo görünmemesi |
| Yalnızca test, belge, yeniden düzenleme (kullanıcı fark etmez) | artış yok | CHANGELOG'a da yazılmaz |

- **1.0.0 öncesi** (`0.y.z`): her sprint/özellik MINOR, düzeltmeler PATCH. Uyumsuzluk da MINOR'da olabilir ama CHANGELOG'da açıkça yaz.
- **1.0.0** = ilk paketlenip Ege'nin kullandığı sürüm (Sprint 5). Ondan sonra yukarıdaki tablo birebir uygulanır.
- Bir sürüme birden fazla türde değişiklik girdiyse en büyüğü belirler. Artışta alt parçalar sıfırlanır (`0.3.1` → `0.4.0`).
- Ön sürüm gerekirse: `1.1.0-beta.1` (Ege'ye sormadan kullanma).

## CHANGELOG.md
- Kökte, [Keep a Changelog](https://keepachangelog.com/tr-TR/1.1.0/) biçiminde, **Türkçe ve kullanıcının diliyle**
  ("Keşfet'te tür filtresi", "kapanırken çökme düzeltildi"), teknik ayrıntı değil.
- Gruplar: `Eklendi`, `Değişti`, `Düzeltildi`, `Kaldırıldı` (gerekirse `Güvenlik`).
- Kullanıcıya görünen her değişiklik **aynı commit'te** `## [Yayınlanmadı]` altına bir satır ekler.
- Sürüm çıkarken `[Yayınlanmadı]` başlığı `## [x.y.z] - YYYY-AA-GG` olur, üstüne yeni boş `[Yayınlanmadı]` açılır.

## Sürüm çıkarma adımları
1. `[Yayınlanmadı]` altındakilere bak, tabloya göre artışı belirle. Emin değilsen Ege'ye sor.
2. `Directory.Build.props` → `<Version>` güncelle.
3. CHANGELOG'da başlığı sürüm + bugünün tarihiyle değiştir, yeni boş `[Yayınlanmadı]` ekle.
4. Derle + test (`CLAUDE.md` komutları). Ayarlar → Hakkında'da yeni sürüm görünmeli.
5. Commit: `Release x.y.z` (gövdeye öne çıkanlar).
6. Annotated tag: `git tag -a vx.y.z -m "x.y.z"` — tag her zaman `v` ön ekli, sürüm commit'inin üstünde.
7. Push: `git push` ve `git push origin vx.y.z` (tag'ler ayrıca gönderilir).
8. Paket ve GitHub Release: `.\scripts\publish.ps1 -Upload` (Velopack; `$env:GITHUB_TOKEN` gerekir, Ege'den iste).
   Release adı `Antenim Yok x.y.z`, tag `vx.y.z`; açıklamaya CHANGELOG'daki o sürümün maddelerini koy.
   Kurulu uygulamalar bu Release'i birkaç saat içinde kendiliğinden indirir — yayınlamadan önce `-Install` ile bu PC'de dene.

## Yapma
- Tag'i taşıma/silme veya yayınlanmış bir sürümü yeniden kullanma; hata varsa yeni PATCH çıkar.
- Sürüm numarasını sadece "commit attım" diye artırma; artış sürüm çıkarırken bir kez yapılır.
- Sürümü koda sabit string olarak yazma.
