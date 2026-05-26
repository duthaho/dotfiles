#Requires -Version 7.0
[CmdletBinding()]
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
# winget exits non-zero on "already installed"; manual $LASTEXITCODE check
# below depends on PS not aborting first.
$PSNativeCommandUseErrorActionPreference = $false

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error @'
winget is not installed. Install it from:
  ms-appinstaller:?source=https://aka.ms/getwinget
Or via the Microsoft Store: "App Installer".
'@
    exit 1
}

$DotfilesRoot = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $DotfilesRoot 'install\packages\winget-packages.json'

if (-not (Test-Path $ManifestPath)) {
    Write-Error "winget manifest not found: $ManifestPath"
    exit 1
}

$Manifest = Get-Content -Raw $ManifestPath | ConvertFrom-Json
$Packages = $Manifest.packages

foreach ($pkg in $Packages) {
    if ($pkg -eq 'Microsoft.PowerShell') {
        Write-Host "==> Skipping $pkg (already running this shell)"
        continue
    }
    Write-Host "==> winget install $pkg"
    if ($DryRun) { continue }
    winget install --id $pkg --silent `
        --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "  winget exited $LASTEXITCODE for $pkg (continuing)"
    }
}

# Nerd Font: skipped in non-interactive (no font picker UI on headless runners).
if (-not $DryRun -and -not $env:NON_INTERACTIVE) {
    $alreadyInstalled = $false
    foreach ($scope in 'HKCU:', 'HKLM:') {
        try {
            $fontKey = Get-ItemProperty `
                -Path "$scope\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" `
                -ErrorAction SilentlyContinue
            if ($fontKey) {
                $match = $fontKey.PSObject.Properties |
                    Where-Object { $_.Name -like 'JetBrainsMono NF*' }
                if ($match) { $alreadyInstalled = $true; break }
            }
        } catch { }
    }

    if ($alreadyInstalled) {
        Write-Host '==> JetBrainsMono Nerd Font already installed, skipping'
    } elseif (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        Write-Host '==> Installing JetBrainsMono Nerd Font via oh-my-posh'
        # --user caused silent failures on some oh-my-posh versions; leave it off.
        oh-my-posh font install JetBrainsMono
        if ($LASTEXITCODE -ne 0) {
            Write-Warning '  Font install exited non-zero. Try manually: oh-my-posh font install JetBrainsMono'
        } else {
            Write-Host '  Font installed. Close ALL Windows Terminal windows and reopen for it to take effect.'
        }
    } else {
        Write-Warning '  oh-my-posh not on PATH yet; rerun bootstrap or install font manually'
    }
}

Write-Host "==> Prereqs done."
