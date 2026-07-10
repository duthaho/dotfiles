#Requires -Version 7.0
<#
.SYNOPSIS
    Symlink helper — stow-equivalent for Windows.

.DESCRIPTION
    Walks the file tree inside each named module folder and creates
    symbolic links under the target (default $HOME) pointing back into
    the dotfiles repo.

    Idempotent: existing correct links are skipped; links that point
    elsewhere into the repo are re-pointed silently (they're ours).

    Conflict flow — a real file, or a symlink NOT owned by this repo,
    sitting where a link must go:
      interactive:      prompt per conflict: [s]kip / [b]ackup / [A]ll
      -NonInteractive:  auto-backup every conflict
    Backups are moved to <target>/.dotfiles-backup/<yyyyMMdd-HHmmss>/<relative-path>.
    The directory is created only when a backup actually happens and is
    unique per run. Foreign symlinks are backed up (the link itself moves,
    its destination is never touched) — never silently replaced.

.PARAMETER Modules
    Array of module folder names (e.g. 'pwsh','wt','git').

.PARAMETER Remove
    Remove links instead of creating them. Only removes symlinks that
    point into the dotfiles repo.

.PARAMETER DryRun
    Print actions (including planned conflict resolutions) without
    performing them.

.PARAMETER NonInteractive
    Resolve every conflict by backing up the existing file (CI /
    unattended installs).

.PARAMETER DotfilesPath
    Override the repo path (defaults to parent of this script).

.PARAMETER TargetPath
    Override the link destination root (defaults to $HOME). Mostly for tests.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string[]]$Modules,
    [switch]$Remove,
    [switch]$DryRun,
    [switch]$NonInteractive,
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

# --- Preflight: symlink creation requires Developer Mode OR admin (Windows only) ---
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

if ($IsWindows -and -not $Remove -and -not (Test-CanCreateSymlinks)) {
    Write-Error @'
Symlink creation requires either:
  (a) Windows Developer Mode enabled
      Settings → Privacy & Security → For developers → Developer Mode = On
  (b) Running this script in an elevated (admin) PowerShell
'@
    exit 1
}

# --- Backup machinery: lazy, unique per run ---
$script:BackupRoot = Join-Path $TargetPath '.dotfiles-backup'
$script:BackupDir  = $null
$script:BackupAll  = $false

function Get-BackupDir {
    if (-not $script:BackupDir) {
        $base = Join-Path $script:BackupRoot (Get-Date -Format 'yyyyMMdd-HHmmss')
        $dir = $base
        $n = 2
        while (Test-Path $dir) {
            $dir = "$base-$n"
            $n++
        }
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $script:BackupDir = $dir
    }
    return $script:BackupDir
}

function Backup-One {
    param([string]$Target, [string]$Relative)
    $dest = Join-Path (Get-BackupDir) $Relative
    $parent = Split-Path -Parent $dest
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Move-Item -Path $Target -Destination $dest -Force
    Write-Host "    backed up: $Target -> $dest"
}

# Decide what to do with a conflict. Returns 's' (skip) or 'b' (backup).
function Resolve-Conflict {
    param([string]$Target, [string]$Kind)

    if ($NonInteractive -or $script:BackupAll) { return 'b' }
    while ($true) {
        $ans = Read-Host "    conflict: $Target exists ($Kind). [s]kip / [b]ackup then link / [A] backup all"
        switch -CaseSensitive ($ans) {
            { $_ -in 's', 'S' } { return 's' }
            { $_ -in 'b', 'B' } { return 'b' }
            'A'                 { $script:BackupAll = $true; return 'b' }
            default             { Write-Host '    please answer s, b, or A' }
        }
    }
}

# --- Worker functions ---
function Invoke-LinkOne {
    param([string]$Source, [string]$Target, [string]$Relative)

    $conflictKind = $null

    if (Test-Path $Target) {
        $item = Get-Item $Target -Force
        if ($item.LinkType -eq 'SymbolicLink') {
            if ($item.Target -eq $Source) {
                Write-Host "  = $Target (already linked)"
                return
            }
            if ($item.Target -and $item.Target.StartsWith($DotfilesPath, [StringComparison]::OrdinalIgnoreCase)) {
                # Ours, but pointing at a stale repo path — safe to re-point.
                Write-Host "  ~ $Target → $($item.Target) (ours, re-pointing)"
                if (-not $DryRun) { Remove-Item $Target -Force }
            } else {
                $conflictKind = "symlink → $($item.Target)"
            }
        } else {
            $conflictKind = 'real file'
        }

        if ($conflictKind) {
            if ($DryRun) {
                if ($NonInteractive) {
                    Write-Host "  ! $Target ($conflictKind) — would back up to $script:BackupRoot\<run>\ and link"
                } else {
                    Write-Host "  ! $Target ($conflictKind) — would prompt [s]kip / [b]ackup / [A]ll"
                }
                return
            }
            $action = Resolve-Conflict -Target $Target -Kind $conflictKind
            if ($action -eq 's') {
                Write-Host "  s $Target (kept existing, skipped)"
                return
            }
            Backup-One -Target $Target -Relative $Relative
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
        $target   = Join-Path $TargetPath $relative

        if ($Remove) {
            Invoke-UnlinkOne -Source $_.FullName -Target $target
        } else {
            Invoke-LinkOne   -Source $_.FullName -Target $target -Relative $relative
        }
    }
}
