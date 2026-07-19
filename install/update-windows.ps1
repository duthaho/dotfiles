#Requires -Version 7.0
<#
.SYNOPSIS
    Pull, re-stow, and flag package-manifest changes (Windows twin of update.sh).

.DESCRIPTION
    git pull --ff-only, re-link the default modules, and if the pull brought in
    changes under install/packages/ (which re-stowing does NOT install), say so
    and offer to run bootstrap — then run doctor so you end on a known state.

.PARAMETER NoDoctor
    Skip the closing health check.

.PARAMETER NonInteractive
    Never prompt; print a notice instead (CI / scripted).

.PARAMETER DotfilesPath
    Override the repo path (defaults to parent of this script's dir).
#>

[CmdletBinding()]
param(
    [switch]$NoDoctor,
    [switch]$NonInteractive,
    [string]$DotfilesPath
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

if (-not $DotfilesPath) { $DotfilesPath = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }

Push-Location $DotfilesPath
try {
    $before = (& git rev-parse HEAD).Trim()
    Write-Host '==> git pull --ff-only'
    & git pull --ff-only
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $after = (& git rev-parse HEAD).Trim()

    Write-Host '==> re-stow default modules'
    & (Join-Path $DotfilesPath 'install/symlink-windows.ps1') `
        -Modules @('git', 'pwsh', 'wt') -DotfilesPath $DotfilesPath

    $changed = @()
    if ($before -ne $after) {
        $changed = @(& git diff --name-only $before $after -- install/packages/) | Where-Object { $_ }
    }

    if ($changed) {
        Write-Host ''
        Write-Host '==> Package manifests changed in this pull:'
        $changed | ForEach-Object { Write-Host "      $_" }
        Write-Host '    Re-stowing does NOT install packages — a bootstrap does.'
        if ($NonInteractive) {
            Write-Host '    Run: dot bootstrap'
        } else {
            $resp = Read-Host "    Run 'dot bootstrap' now to install them? [y/N]"
            if ($resp -eq 'y' -or $resp -eq 'Y') {
                & (Join-Path $DotfilesPath 'bootstrap.ps1')
                exit $LASTEXITCODE
            }
            Write-Host "    Skipped. Run 'dot bootstrap' when ready."
        }
    } elseif ($before -eq $after) {
        Write-Host '==> Already up to date.'
    }

    if (-not $NoDoctor) {
        Write-Host ''
        Write-Host '==> doctor'
        & (Join-Path $DotfilesPath 'doctor.ps1')
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}
