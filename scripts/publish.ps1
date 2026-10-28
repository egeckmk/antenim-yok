<#
.SYNOPSIS
    Builds an Antenim Yok release with Velopack: Setup.exe + update packages, optionally uploaded to GitHub.

.DESCRIPTION
    - Version comes from Directory.Build.props (rules: .claude/skills/versioning).
    - Output: artifacts\releases\  ->  AntenimYok-Setup.exe (installer), *-full.nupkg / *-delta.nupkg,
      releases.win.json (update feed), AntenimYok-Portable.zip.
    - Installed app: %LOCALAPPDATA%\Ege.AntenimYok (no admin). Favorites/settings stay in %LOCALAPPDATA%\AntenimYok.
    - The app updates itself from GitHub Releases of github.com/egeckmk/antenim-yok.
    - -Upload needs a GitHub token in $env:GITHUB_TOKEN (fine-grained, "Contents: read and write" on this repo).
      Never put the token in the repo.

.EXAMPLE
    .\scripts\publish.ps1                 # build Setup.exe locally
    .\scripts\publish.ps1 -Install        # build and run Setup.exe on this PC
    .\scripts\publish.ps1 -Upload         # build and publish the GitHub release vX.Y.Z (tag must exist)
#>
[CmdletBinding()]
param(
    [switch]$Install,
    [switch]$Upload
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$repoUrl = 'https://github.com/egeckmk/antenim-yok'
$packId = 'Ege.AntenimYok'

$version = ([xml](Get-Content (Join-Path $root 'Directory.Build.props'))).Project.PropertyGroup.Version |
    Where-Object { $_ } | Select-Object -First 1
if (-not $version) { throw 'Version not found in Directory.Build.props.' }
if ($Upload -and -not $env:GITHUB_TOKEN) { throw 'Set $env:GITHUB_TOKEN first (see the help above).' }

$publishDir = Join-Path $root "artifacts\publish\$version"
$releasesDir = Join-Path $root 'artifacts\releases'
Push-Location $root
try {
    & dotnet tool restore | Out-Null

    Write-Host "Antenim Yok $version derleniyor..." -ForegroundColor Cyan
    if (Test-Path $publishDir) { Remove-Item $publishDir -Recurse -Force }
    & dotnet publish src\AntenimYok.App\AntenimYok.App.csproj -c Release -r win-x64 -p:Platform=x64 -o $publishDir --nologo -v quiet
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed ($LASTEXITCODE)." }

    # Start from what is on GitHub only: stale local packages (never published) would end up in the update feed
    # and make the upload fail. The previous release is downloaded so vpk can build a small delta update.
    if (Test-Path $releasesDir) { Remove-Item $releasesDir -Recurse -Force }
    New-Item -ItemType Directory -Force $releasesDir | Out-Null
    $downloadArgs = @('vpk', 'download', 'github', '--repoUrl', $repoUrl, '-o', $releasesDir)
    if ($env:GITHUB_TOKEN) { $downloadArgs += @('--token', $env:GITHUB_TOKEN) }
    & dotnet @downloadArgs 2>&1 | Out-Null

    Write-Host 'Kurulum paketi hazırlanıyor (Velopack)...' -ForegroundColor Cyan
    & dotnet vpk pack --packId $packId --packVersion $version --packDir $publishDir `
        --mainExe AntenimYok.exe --packTitle 'Antenim Yok' --packAuthors 'Ege' `
        --icon src\AntenimYok.App\Assets\AppIcon.ico --shortcuts None --runtime win-x64 -o $releasesDir
    if ($LASTEXITCODE -ne 0) { throw "vpk pack failed ($LASTEXITCODE)." }

    $setup = Join-Path $releasesDir "$packId-win-Setup.exe"
    if (-not (Test-Path $setup)) { $setup = Get-ChildItem $releasesDir -Filter '*Setup.exe' | Select-Object -First 1 -ExpandProperty FullName }
    Write-Host "Hazır: $setup" -ForegroundColor Green

    if ($Upload) {
        Write-Host "GitHub'a yükleniyor: v$version" -ForegroundColor Cyan
        & dotnet vpk upload github --repoUrl $repoUrl --token $env:GITHUB_TOKEN -o $releasesDir `
            --publish --releaseName "Antenim Yok $version" --tag "v$version"
        if ($LASTEXITCODE -ne 0) { throw "vpk upload failed ($LASTEXITCODE)." }
        Write-Host "Yayınlandı: $repoUrl/releases/tag/v$version" -ForegroundColor Green
    }

    if ($Install) {
        # No -Wait: it would also wait for the app that Setup starts at the end.
        Write-Host 'Kurulum başlatılıyor...'
        Start-Process $setup
    }
}
finally {
    Pop-Location
}
$global:LASTEXITCODE = 0
