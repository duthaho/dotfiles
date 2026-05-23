#Requires -Version 7.0
<#
.SYNOPSIS
    Post-install verification for the Windows-native dotfiles install.
#>
[CmdletBinding()]
param([string]$DotfilesPath)

if (-not $DotfilesPath) { $DotfilesPath = $PSScriptRoot }

$Pass = 0; $Fail = 0
function Ok   ($msg) { Write-Host "  [PASS] $msg" -ForegroundColor Green; $script:Pass++ }
function Fail ($msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red;   $script:Fail++ }
function Info ($msg) { Write-Host "  [INFO] $msg" -ForegroundColor Yellow }

function Check-Bin {
    param($Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { Ok "$Name on PATH ($($cmd.Source))" } else { Fail "$Name NOT on PATH" }
}

function Check-Symlink {
    param($Path, $ExpectedPrefix)
    if (-not (Test-Path $Path)) { Fail "$Path does not exist"; return }
    $item = Get-Item $Path -Force
    if ($item.LinkType -ne 'SymbolicLink') { Fail "$Path is not a symlink"; return }
    if ($item.Target -like "*$ExpectedPrefix*") {
        Ok "$Path → $($item.Target)"
    } else {
        Fail "$Path → $($item.Target) (expected under $ExpectedPrefix)"
    }
}

Write-Host "== Required binaries =="
Check-Bin git
Check-Bin pwsh
Check-Bin 'oh-my-posh'
Check-Bin starship    # may be absent on Windows; that's ok if not used

Write-Host ""
Write-Host "== Identity =="
$gcl = Join-Path $HOME '.gitconfig.local'
if (Test-Path $gcl) {
    Ok '~\.gitconfig.local exists'
    $n = git config --get user.name 2>$null
    $e = git config --get user.email 2>$null
    if ($n -and $e) { Ok "git identity resolves: $n <$e>" }
    else { Fail 'git user.name/user.email do not resolve' }
} else {
    Fail '~\.gitconfig.local missing'
}

Write-Host ""
Write-Host "== Symlinks =="
$psProfile = Join-Path $HOME 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
$wtSettings = Join-Path $HOME 'AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
$gitConfig = Join-Path $HOME '.gitconfig'

Check-Symlink $psProfile  $DotfilesPath
Check-Symlink $wtSettings $DotfilesPath
Check-Symlink $gitConfig  $DotfilesPath

Write-Host ""
Write-Host "== Optional =="
if (Get-Command nvim -ErrorAction SilentlyContinue) {
    Ok 'nvim installed'
    $nvimInit = Join-Path $HOME '.config\nvim\init.lua'
    if (Test-Path $nvimInit) { Ok 'nvim config present' }
    else { Info 'nvim installed but config not symlinked' }
} else {
    Info 'nvim not installed (opt-in)'
}

Write-Host ""
Write-Host "== Summary =="
Write-Host "  Passed: $Pass"
Write-Host "  Failed: $Fail"
exit ([int]($Fail -gt 0))
