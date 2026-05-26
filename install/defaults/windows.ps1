#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('apply', 'revert')]
    [string]$Subcommand = 'apply',

    [Parameter(Position = 1)]
    [string]$Snapshot
)

$ErrorActionPreference = 'Stop'

$SnapshotDir = Join-Path $HOME '.dotfiles-defaults-backup'
New-Item -ItemType Directory -Path $SnapshotDir -Force | Out-Null

$Entries = [System.Collections.ArrayList]::new()

function Apply-Default {
    param($Path, $Name, $Type, $Value)
    $prev = $null
    $prevPresent = $false
    if (Test-Path $Path) {
        $cur = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        if ($cur -and $null -ne $cur.$Name) {
            $prev = $cur.$Name
            $prevPresent = $true
        }
    } else {
        New-Item -Path $Path -Force | Out-Null
    }
    Set-ItemProperty -Path $Path -Name $Name -Type $Type -Value $Value
    [void]$Entries.Add([PSCustomObject]@{
        path             = $Path
        name             = $Name
        type             = "$Type"
        previous         = $prev
        previous_present = $prevPresent
        applied          = $Value
    })
}

function Apply-All {
    $explorerAdv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Apply-Default $explorerAdv 'HideFileExt'        DWord 0
    Apply-Default $explorerAdv 'Hidden'             DWord 1
    Apply-Default $explorerAdv 'LaunchTo'           DWord 1
    Apply-Default $explorerAdv 'AlwaysShowMenus'    DWord 1
    Apply-Default $explorerAdv 'TaskbarAl'          DWord 0
    Apply-Default $explorerAdv 'TaskbarDa'          DWord 0
    Apply-Default $explorerAdv 'TaskbarMn'          DWord 0
    Apply-Default $explorerAdv 'ShowCopilotButton'  DWord 0

    $search = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
    Apply-Default $search 'BingSearchEnabled' DWord 0
    Apply-Default $search 'CortanaConsent'    DWord 0

    $themes = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    Apply-Default $themes 'AppsUseLightTheme'   DWord 0
    Apply-Default $themes 'SystemUsesLightTheme' DWord 0

    $kbd = 'HKCU:\Control Panel\Keyboard'
    Apply-Default $kbd 'KeyboardDelay' String '0'
    Apply-Default $kbd 'KeyboardSpeed' String '31'

    $mouse = 'HKCU:\Control Panel\Mouse'
    Apply-Default $mouse 'MouseSpeed'      String '0'
    Apply-Default $mouse 'MouseThreshold1' String '0'
    Apply-Default $mouse 'MouseThreshold2' String '0'
}

function Write-Snapshot {
    param($Path, $Timestamp)
    $payload = [PSCustomObject]@{
        platform  = 'windows'
        timestamp = $Timestamp
        entries   = $Entries
    }
    $payload | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding utf8
}

function Restart-Explorer {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
        Start-Process explorer
    }
}

switch ($Subcommand) {
    'apply' {
        $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH-mm-ssZ')
        $snap = Join-Path $SnapshotDir "$ts.json"
        Write-Host "==> Applying Windows defaults (snapshot: $snap)"
        Apply-All
        Write-Snapshot -Path $snap -Timestamp $ts
        Write-Host '==> Restarting Explorer'
        Restart-Explorer
        Write-Host "==> Done. Revert with: $PSCommandPath revert $snap"
    }
    'revert' {
        if (-not $Snapshot) {
            Write-Error 'usage: windows.ps1 revert <snapshot.json>'
            exit 2
        }
        if (-not (Test-Path $Snapshot)) {
            Write-Error "snapshot not found: $Snapshot"
            exit 1
        }
        Write-Host "==> Reverting from $Snapshot"
        $data = Get-Content -Raw $Snapshot | ConvertFrom-Json
        foreach ($e in $data.entries) {
            if ($e.previous_present) {
                Set-ItemProperty -Path $e.path -Name $e.name -Type $e.type -Value $e.previous
            } else {
                Remove-ItemProperty -Path $e.path -Name $e.name -ErrorAction SilentlyContinue
            }
        }
        Restart-Explorer
        Write-Host '==> Reverted.'
    }
}
