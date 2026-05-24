#Requires -Version 7.0
<#
.SYNOPSIS
    Bootstrap a Windows machine: install toolchain, seed identity,
    symlink Windows modules. Mirrors bootstrap.sh.
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$InstallNvim,
    [string]$DotfilesPath
)

$ErrorActionPreference = 'Stop'

if (-not $DotfilesPath) {
    $DotfilesPath = $PSScriptRoot
}
$env:DOTFILES = $DotfilesPath

Write-Host "==> Dotfiles repo: $DotfilesPath"
if ($DryRun) { Write-Host "==> DRY RUN" }

# 1. Prereqs
& "$DotfilesPath\install\prereqs-windows.ps1" -DryRun:$DryRun

# 2. Identity
if (-not $DryRun) {
    & "$DotfilesPath\install\seed-identity.ps1"
}

# 3. Symlink Windows default modules
$WinDefaults = @('git','pwsh','wt')
& "$DotfilesPath\install\symlink-windows.ps1" `
    -Modules $WinDefaults `
    -DryRun:$DryRun `
    -DotfilesPath $DotfilesPath

# 4. Optional: nvim
if (-not $DryRun) {
    $doNvim = $InstallNvim
    if (-not $doNvim) {
        $resp = Read-Host 'Install Neovim config? [y/N]'
        $doNvim = ($resp -eq 'y' -or $resp -eq 'Y')
    }
    if ($doNvim) {
        winget install --id Neovim.Neovim --silent `
            --accept-source-agreements --accept-package-agreements
        & "$DotfilesPath\install\symlink-windows.ps1" `
            -Modules @('nvim') -DotfilesPath $DotfilesPath
    }
}

# 5. Install PowerShell modules used by profile (PSReadLine ships with pwsh)
if (-not $DryRun) {
    foreach ($mod in @('posh-git', 'Terminal-Icons')) {
        if (-not (Get-Module -ListAvailable -Name $mod)) {
            Write-Host "==> Install-Module $mod"
            Install-Module -Name $mod -Scope CurrentUser -Force -AllowClobber `
                -ErrorAction Continue
        }
    }
}

Write-Host ""
Write-Host "==> Bootstrap complete. Open a new PowerShell 7 window."
Write-Host "==> Verify with: $DotfilesPath\doctor.ps1"

# Nudge user to authenticate with GitHub if gh is installed but not signed in.
if (-not $DryRun -and (Get-Command gh -ErrorAction SilentlyContinue)) {
    & gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "==> Next: run 'gh auth login' to set up GitHub SSH + credential helper"
    }
}
