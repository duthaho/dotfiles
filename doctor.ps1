#Requires -Version 7.0
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

function Check-Bin-Info {
    param($Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { Ok "$Name on PATH ($($cmd.Source))" } else { Info "$Name not installed (optional)" }
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
    # Read via --file: CI sets GIT_CONFIG_GLOBAL to a temp file, breaking the
    # ~/.gitconfig [include] chain. Sidecar is the contract per README.
    $n = git config --file $gcl --get user.name 2>$null
    $e = git config --file $gcl --get user.email 2>$null
    if ($n -and $e) { Ok "git identity resolves: $n <$e>" }
    else { Fail 'git user.name/user.email do not resolve in ~\.gitconfig.local' }
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
Write-Host "== CLI cluster (optional) =="
Check-Bin-Info zoxide
Check-Bin-Info atuin
Check-Bin-Info bat
Check-Bin-Info fd
Check-Bin-Info delta

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
Write-Host "== OS defaults =="
$match = 0; $total = 3
$expected = @(
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'HideFileExt'; Value = 0 },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'AppsUseLightTheme'; Value = 0 },
    @{ Path = 'HKCU:\Control Panel\Keyboard'; Name = 'KeyboardSpeed'; Value = '31' }
)
foreach ($e in $expected) {
    $cur = (Get-ItemProperty -Path $e.Path -Name $e.Name -ErrorAction SilentlyContinue).$($e.Name)
    if ($null -ne $cur -and "$cur" -eq "$($e.Value)") { $match++ }
}
if ($match -eq $total) {
    Ok "OS defaults applied ($match/$total spot-checks match)"
} elseif ($match -eq 0) {
    Info "OS defaults not applied (run: .\bootstrap.ps1 -ApplyDefaults)"
} else {
    Info "OS defaults partial ($match/$total spot-checks match)"
}

Write-Host ""
Write-Host "== Summary =="
Write-Host "  Passed: $Pass"
Write-Host "  Failed: $Fail"
exit ([int]($Fail -gt 0))
