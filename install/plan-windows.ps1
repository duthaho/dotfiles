#Requires -Version 7.0
<#
.SYNOPSIS
    Read-only drift report (Windows twin of plan.sh).

.DESCRIPTION
    Answers "if I ran bootstrap now, what would change?" without changing
    anything. Sections: symlinks (would symlink-windows link/back up?), packages
    (winget ids from the manifest installed?), and an OS-defaults note. Touches
    nothing.

.PARAMETER DotfilesPath
    Override the repo path (defaults to parent of this script's dir).

.PARAMETER TargetPath
    Override the link root (defaults to $HOME). Mostly for tests.

.OUTPUTS
    Exit 0 = matches repo intent; 2 = drift; 1 = error.
#>

[CmdletBinding()]
param(
    [string]$DotfilesPath,
    [string]$TargetPath
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

if (-not $DotfilesPath) { $DotfilesPath = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
if (-not $TargetPath)   { $TargetPath = $HOME }

function Write-Ok   { param($m) Write-Host "  [+] $m" }
function Write-Bad  { param($m) Write-Host "  [x] $m" }
function Write-Info { param($m) Write-Host "  [-] $m" }

$script:Drift = 0

# A target is "linked" when it is a symlink resolving into the repo. (Windows
# links are always file-level — symlink-windows.ps1 never folds directories.)
function Get-LinkState {
    param([string]$Target, [string]$Source)
    if (-not (Test-Path $Target)) { return 'missing' }
    $item = Get-Item $Target -Force
    if ($item.LinkType -eq 'SymbolicLink' -and $item.Target -eq $Source) { return 'linked' }
    return 'conflict'   # real file, or a symlink we don't own
}

function Plan-Module {
    param([string]$Module)
    $modPath = Join-Path $DotfilesPath $Module
    if (-not (Test-Path $modPath)) { return }

    $linked = 0; $conflict = 0; $missing = 0; $lines = @()
    Get-ChildItem -Path $modPath -Recurse -File -Force | ForEach-Object {
        $rel    = $_.FullName.Substring($modPath.Length + 1)
        $target = Join-Path $TargetPath $rel
        switch (Get-LinkState -Target $target -Source $_.FullName) {
            'linked'   { $linked++ }
            'conflict' { $conflict++; $lines += "        ~\$rel (would back up + link)"; $script:Drift++ }
            'missing'  { $missing++;  $lines += "        ~\$rel (would link)";           $script:Drift++ }
        }
    }
    if (($conflict + $missing) -eq 0) {
        Write-Ok "$Module ($linked linked)"
    } else {
        Write-Bad "$Module ($linked linked, $conflict conflict, $missing missing)"
        $lines | ForEach-Object { Write-Host $_ }
    }
}

Write-Host "==> Plan for $DotfilesPath on windows (read-only)"
Write-Host ''
Write-Host 'Symlinks'
foreach ($m in @('git', 'pwsh', 'wt')) { Plan-Module $m }
# nvim is opt-in — report only once at least one target exists.
$nvimPath = Join-Path $DotfilesPath 'nvim'
if (Test-Path $nvimPath) {
    $any = Get-ChildItem $nvimPath -Recurse -File -Force | Where-Object {
        Test-Path (Join-Path $TargetPath $_.FullName.Substring($nvimPath.Length + 1))
    }
    if ($any) { Plan-Module 'nvim' }
}

# --- packages (winget) ------------------------------------------------------
Write-Host ''
Write-Host 'Packages'
$manifest = Join-Path $DotfilesPath 'install/packages/winget-packages.json'
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Info 'winget not found (skipping)'
} elseif (-not (Test-Path $manifest)) {
    Write-Info 'winget-packages.json not found (skipping)'
} else {
    # Manifest is a flat { "packages": ["Publisher.Id", ...] } list.
    $json = Get-Content $manifest -Raw | ConvertFrom-Json
    $ids = @($json.packages) | Where-Object { $_ }

    if (-not $ids) {
        Write-Info 'no package ids found in manifest (skipping)'
    } else {
        $installed = (& winget list) 2>$null | Out-String
        $missing = $ids | Where-Object { $installed -notmatch [regex]::Escape($_) }
        if (-not $missing) {
            Write-Ok "$($ids.Count)/$($ids.Count) winget packages installed"
        } else {
            Write-Bad "$($ids.Count - $missing.Count)/$($ids.Count) installed; missing: $($missing -join ', ')"
            $script:Drift++
        }
    }
}

# --- OS defaults ------------------------------------------------------------
Write-Host ''
Write-Host 'OS defaults'
Write-Info 'opt-in on Windows (apply/revert with: dot defaults)'

# --- summary ----------------------------------------------------------------
Write-Host ''
if ($script:Drift -eq 0) {
    Write-Host '==> In sync — bootstrap/stow would change nothing.'
    exit 0
} else {
    Write-Host "==> $($script:Drift) drifted area(s). Run 'dot bootstrap' (or 'dot stow <module>') to converge."
    exit 2
}
