#Requires -Version 7.0
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Position = 0)]
    [string]$Command = 'help',

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$ErrorActionPreference = 'Stop'

$DotRepo = if ($env:DOTFILES) { $env:DOTFILES } else { Split-Path -Parent $PSScriptRoot }

function Show-Usage {
    Write-Host @"
Usage: dot <command> [args]

Commands:
  bootstrap [flags]              Run the full bootstrap
  doctor                         Run health checks
  stow <module>                  Symlink a specific module (e.g., nvim)
  defaults <apply|revert [snap]> Apply or revert OS defaults (Windows)
  update                         git pull --ff-only + re-stow default modules
  plan                           Read-only drift report (what bootstrap would change)
  uninstall [-DryRun]            Remove all repo-owned symlinks (teardown)
  fork-check [-Staged]           Scan for leaked identity/secrets
  fork-check --install-hook      Enable the pre-commit fork-safety hook
  help                           Show this message
"@
}

switch ($Command) {
    'bootstrap' {
        & "$DotRepo\bootstrap.ps1" @Rest
        exit $LASTEXITCODE
    }
    'doctor' {
        & "$DotRepo\doctor.ps1" @Rest
        exit $LASTEXITCODE
    }
    'stow' {
        & "$DotRepo\install\symlink-windows.ps1" -Modules $Rest -DotfilesPath $DotRepo
        exit $LASTEXITCODE
    }
    'defaults' {
        & "$DotRepo\install\defaults\windows.ps1" @Rest
        exit $LASTEXITCODE
    }
    'update' {
        & "$DotRepo\install\update-windows.ps1" @Rest -DotfilesPath $DotRepo
        exit $LASTEXITCODE
    }
    'plan' {
        & "$DotRepo\install\plan-windows.ps1" @Rest -DotfilesPath $DotRepo
        exit $LASTEXITCODE
    }
    'uninstall' {
        & "$DotRepo\install\uninstall-windows.ps1" @Rest -DotfilesPath $DotRepo
        exit $LASTEXITCODE
    }
    'fork-check' {
        if ($Rest -contains '--install-hook' -or $Rest -contains '-InstallHook') {
            git -C $DotRepo config core.hooksPath .githooks
            Write-Host '==> pre-commit fork-safety hook enabled (core.hooksPath=.githooks)'
            exit 0
        }
        & "$DotRepo\install\fork-safety-scan.ps1" @Rest -DotfilesPath $DotRepo
        exit $LASTEXITCODE
    }
    { $_ -in 'help', '--help', '-h' } { Show-Usage }
    default {
        Write-Error "unknown command: $Command (run: dot help)" -ErrorAction Continue
        exit 2
    }
}
