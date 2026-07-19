#Requires -Version 7.0
<#
.SYNOPSIS
    Wholesale teardown — remove every repo-owned symlink (Windows).

.DESCRIPTION
    Delegates to symlink-windows.ps1 -Remove, which only removes symlinks that
    point into the dotfiles repo. Real files and foreign symlinks are never
    touched. Pre-install backups under <target>\.dotfiles-backup\ are left in
    place; the newest one's path is printed so you can restore by hand.

.PARAMETER DryRun
    Print what would be removed without performing it.

.PARAMETER DotfilesPath
    Override the repo path (defaults to parent of this script's dir).

.PARAMETER TargetPath
    Override the link root (defaults to $HOME). Mostly for tests.
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$DotfilesPath,
    [string]$TargetPath
)

$ErrorActionPreference = 'Stop'

if (-not $DotfilesPath) {
    $DotfilesPath = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
}
if (-not $TargetPath) {
    $TargetPath = $HOME
}

# Full module set; removing links a module never created is a harmless no-op.
$modules = @('git', 'pwsh', 'wt', 'nvim', 'kitty')

Write-Host '==> Removing repo-owned symlinks'
& (Join-Path $DotfilesPath 'install/symlink-windows.ps1') `
    -Modules $modules -Remove -DryRun:$DryRun `
    -DotfilesPath $DotfilesPath -TargetPath $TargetPath

# Point the user at their backups; never auto-restore.
$backupRoot = Join-Path $TargetPath '.dotfiles-backup'
if (Test-Path $backupRoot) {
    $latest = Get-ChildItem $backupRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name | Select-Object -Last 1
    if ($latest) {
        Write-Host ''
        Write-Host '==> Your pre-install backups are preserved. Newest:'
        Write-Host "    $($latest.FullName)"
    }
}

Write-Host ''
if ($DryRun) {
    Write-Host '==> Dry run complete — nothing was removed.'
} else {
    Write-Host '==> Uninstall complete. Open a new PowerShell window.'
}
