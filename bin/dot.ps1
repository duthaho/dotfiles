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
        Push-Location $DotRepo
        try {
            git pull --ff-only
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
            & "$DotRepo\install\symlink-windows.ps1" -Modules @('git','pwsh','wt') -DotfilesPath $DotRepo
            exit $LASTEXITCODE
        } finally {
            Pop-Location
        }
    }
    { $_ -in 'help', '--help', '-h' } { Show-Usage }
    default {
        Write-Error "unknown command: $Command (run: dot help)" -ErrorAction Continue
        exit 2
    }
}
