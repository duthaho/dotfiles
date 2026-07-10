#Requires -Version 7.0
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$InstallNvim,
    [switch]$NonInteractive,
    [switch]$ApplyDefaults,
    [string]$DotfilesPath
)

$ErrorActionPreference = 'Stop'
# See install/prereqs-windows.ps1 for rationale.
$PSNativeCommandUseErrorActionPreference = $false

if ($NonInteractive) {
    $env:NON_INTERACTIVE = '1'
}

if (-not $DotfilesPath) {
    $DotfilesPath = $PSScriptRoot
}
$env:DOTFILES = $DotfilesPath
if (-not $DryRun) {
    [Environment]::SetEnvironmentVariable('DOTFILES', $DotfilesPath, 'User')
}

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
    -NonInteractive:$NonInteractive `
    -DotfilesPath $DotfilesPath

# 4. Optional: nvim
if (-not $DryRun) {
    $doNvim = $InstallNvim
    if (-not $doNvim -and -not $NonInteractive) {
        $resp = Read-Host 'Install Neovim config? [y/N]'
        $doNvim = ($resp -eq 'y' -or $resp -eq 'Y')
    }
    if ($doNvim) {
        winget install --id Neovim.Neovim --silent `
            --accept-source-agreements --accept-package-agreements
        & "$DotfilesPath\install\symlink-windows.ps1" `
            -Modules @('nvim') -NonInteractive:$NonInteractive `
            -DotfilesPath $DotfilesPath
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

if (-not $DryRun -and -not $NonInteractive -and $ApplyDefaults) {
    & "$DotfilesPath\install\defaults\windows.ps1" apply
}

Write-Host ""
Write-Host "==> Bootstrap complete. Open a new PowerShell 7 window."
Write-Host "==> Verify with: $DotfilesPath\doctor.ps1"

# Nudge user to authenticate with GitHub if gh is installed but not signed in.
if (-not $DryRun -and (Get-Command gh -ErrorAction SilentlyContinue)) {
    & gh auth status *>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "==> Next: run 'gh auth login' to set up GitHub SSH + credential helper"
    }
}

exit 0
