<#
.SYNOPSIS
    One-click Windows release: asks for the GitHub token in a password dialog, then runs publish.ps1 -Upload.
    Started by release-windows.cmd (double-click).
#>
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = Split-Path $PSScriptRoot -Parent
$repo = 'egeckmk/antenim-yok'
Set-Location $root

Write-Host 'GitHub erişimi kontrol ediliyor...'
try {
    Invoke-WebRequest "https://api.github.com/repos/$repo" -UseBasicParsing -TimeoutSec 15 | Out-Null
}
catch {
    Write-Host "GitHub'a ulaşılamıyor. İş bilgisayarındaysan şirket VPN'ine bağlanıp tekrar çalıştır." -ForegroundColor Red
    return
}

& git pull --ff-only
if ($LASTEXITCODE -ne 0) { Write-Host 'git pull başarısız; önce yerel değişiklikleri kontrol et.' -ForegroundColor Red; return }

$credential = Get-Credential -UserName 'GitHub token' -Message "GitHub token'ını Parola (Password) alanına yapıştır"
if (-not $credential) { Write-Host 'İptal edildi.'; return }
$env:GITHUB_TOKEN = $credential.GetNetworkCredential().Password
$headers = @{ Authorization = "Bearer $env:GITHUB_TOKEN"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'AntenimYok-release' }

try {
    # One-time cleanup: the first release was published as "v1.0.0" before platform-prefixed tags (win-v…).
    try {
        $legacy = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/tags/v1.0.0" -Headers $headers
        Invoke-RestMethod "https://api.github.com/repos/$repo/releases/$($legacy.id)" -Method Delete -Headers $headers | Out-Null
        Write-Host "Eski Release '$($legacy.name)' silindi (v1.0.0 tag'i yerinde kalır)."
    }
    catch {
        if ($_.Exception.Response.StatusCode.value__ -ne 404) { throw }
    }

    & (Join-Path $PSScriptRoot 'publish.ps1') -Upload
}
finally {
    Remove-Item Env:GITHUB_TOKEN -ErrorAction SilentlyContinue
}
Write-Host ''
Write-Host "Bitti. Token'ı GitHub'dan silmeyi unutma: https://github.com/settings/personal-access-tokens" -ForegroundColor Green
