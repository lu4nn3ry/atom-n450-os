# post_rufus_inject.ps1 - Injeta configuracao de Wi-Fi e auto-beacon no pendrive apos o Rufus
param(
    [string]$Drive = "E:"
)

$apkovlSource = Join-Path $PSScriptRoot "localhost.apkovl.tar.gz"

if (-not (Test-Path $apkovlSource)) {
    Write-Host "[ERRO] Arquivo itautec-w7020.apkovl.tar.gz nao encontrado!" -ForegroundColor Red
    exit 1
}

$destDrive = "$($Drive.TrimEnd('\'))\"

Write-Host "[INJECT] Injetando configuracao no pendrive $destDrive..." -ForegroundColor Cyan

# Only ONE *.apkovl.tar.gz may exist on the root, or Alpine ignores all of them
Remove-Item "$($destDrive)*.apkovl.tar.gz" -Force -ErrorAction SilentlyContinue
Copy-Item -Path $apkovlSource -Destination "$($destDrive)localhost.apkovl.tar.gz" -Force
Copy-Item -Path (Join-Path $PSScriptRoot "setup.generated.sh") -Destination "$($destDrive)setup.sh" -Force

# Ajustar syslinux.cfg se existir para carregar o apkovl
$syslinuxCfg = "$($destDrive)boot\syslinux\syslinux.cfg"
if (Test-Path $syslinuxCfg) {
    $content = Get-Content $syslinuxCfg -Raw
    if ($content -notmatch "apkovl=") {
        $content = $content -replace "modules=loop,squashfs,sd-mod,usb-storage quiet", "modules=loop,squashfs,sd-mod,usb-storage apkovl=/itautec-w7020.apkovl.tar.gz quiet"
        Set-Content -Path $syslinuxCfg -Value $content -Force
    }
}

Write-Host "[OK] Pendrive pronto para boot no Itautec W7020 com Wi-Fi automatico!" -ForegroundColor Green
