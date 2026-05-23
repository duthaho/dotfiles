#Requires -Version 7.0
<#
.SYNOPSIS
    Symlink helper — stow-equivalent for Windows.

.DESCRIPTION
    Walks the file tree inside each named module folder and creates
    symbolic links under $HOME pointing back into the dotfiles repo.

    Idempotent: existing correct links are skipped; existing real files
    cause a warning and are skipped (never overwritten).

.PARAMETER Modules
    Array of module folder names (e.g. 'pwsh','wt','git').

.PARAMETER Remove
    Remove links instead of creating them. Only removes symlinks that
    point into the dotfiles repo.

.PARAMETER DryRun
    Print actions without performing them.

.PARAMETER DotfilesPath
    Override the repo path (defaults to parent of this script).

.NOTES
    When a real (non-symlink) file blocks a link, it is automatically moved
    to <target>.bak before the symlink is created. Re-runs that produce a
    new .bak overwrite any previous one — so .bak is always the state from
    the most recent conflict. To keep older backups, rename them yourself
    between runs (e.g., .bak.YYYYMMDD).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string[]]$Modules,
    [switch]$Remove,
    [switch]$DryRun,
    [string]$DotfilesPath
)

$ErrorActionPreference = 'Stop'

if (-not $DotfilesPath) {
    $DotfilesPath = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
}

# --- Preflight: symlink creation requires Developer Mode OR admin ---
function Test-CanCreateSymlinks {
    $devMode = Get-ItemProperty `
        -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
        -Name 'AllowDevelopmentWithoutDevLicense' -ErrorAction SilentlyContinue
    if ($devMode -and $devMode.AllowDevelopmentWithoutDevLicense -eq 1) {
        return $true
    }
    $admin = ([Security.Principal.WindowsPrincipal]`
              [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
                  [Security.Principal.WindowsBuiltInRole]::Administrator)
    return $admin
}

if (-not $Remove -and -not (Test-CanCreateSymlinks)) {
    Write-Error @'
Symlink creation requires either:
  (a) Windows Developer Mode enabled
      Settings → Privacy & Security → For developers → Developer Mode = On
  (b) Running this script in an elevated (admin) PowerShell
'@
    exit 1
}

# --- Worker functions ---
function Invoke-LinkOne {
    param([string]$Source, [string]$Target)

    if (Test-Path $Target) {
        $item = Get-Item $Target -Force
        if ($item.LinkType -eq 'SymbolicLink' -and $item.Target -eq $Source) {
            Write-Host "  = $Target (already linked)"
            return
        }
        if ($item.LinkType -eq 'SymbolicLink') {
            Write-Host "  ~ $Target → $($item.Target) (replacing)"
            if (-not $DryRun) { Remove-Item $Target -Force }
        } else {
            $backup = "$Target.bak"
            Write-Host "  ~ $Target (real file → $backup, then linking)"
            if (-not $DryRun) {
                if (Test-Path $backup) { Remove-Item $backup -Force }
                Move-Item -Path $Target -Destination $backup -Force
            }
        }
    }

    Write-Host "  + $Target → $Source"
    if (-not $DryRun) {
        $parent = Split-Path -Parent $Target
        if (-not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        New-Item -ItemType SymbolicLink -Path $Target -Target $Source | Out-Null
    }
}

function Invoke-UnlinkOne {
    param([string]$Source, [string]$Target)

    if (-not (Test-Path $Target)) {
        Write-Host "  - $Target (not present)"
        return
    }
    $item = Get-Item $Target -Force
    if ($item.LinkType -ne 'SymbolicLink') {
        Write-Warning "  ! $Target is not a symlink — SKIPPING"
        return
    }
    if ($item.Target -ne $Source) {
        Write-Warning "  ! $Target → $($item.Target) (not ours) — SKIPPING"
        return
    }
    Write-Host "  - $Target"
    if (-not $DryRun) { Remove-Item $Target -Force }
}

# --- Main: walk each module ---
foreach ($mod in $Modules) {
    $modPath = Join-Path $DotfilesPath $mod
    if (-not (Test-Path $modPath)) {
        Write-Warning "Module '$mod' not found under $DotfilesPath, skipping"
        continue
    }

    Write-Host "==> $mod"
    Get-ChildItem -Path $modPath -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring($modPath.Length + 1)
        $target   = Join-Path $HOME $relative

        if ($Remove) {
            Invoke-UnlinkOne -Source $_.FullName -Target $target
        } else {
            Invoke-LinkOne   -Source $_.FullName -Target $target
        }
    }
}
