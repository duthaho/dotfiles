#Requires -Version 7.0
<#
.SYNOPSIS
    Install the Windows-native v1 toolchain via winget.
#>
[CmdletBinding()]
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error @'
winget is not installed. Install it from:
  ms-appinstaller:?source=https://aka.ms/getwinget
Or via the Microsoft Store: "App Installer".
'@
    exit 1
}

# Package list — winget IDs, not display names.
$Packages = @(
    'Git.Git',
    'Microsoft.PowerShell',          # PowerShell 7 (separate from Windows PS 5.1)
    'Starship.Starship',
    'JanDeDobbeleer.OhMyPosh',
    'junegunn.fzf',
    'BurntSushi.ripgrep.MSVC',
    'sharkdp.fd',
    'eza-community.eza',
    'jesseduffield.lazygit',
    'Microsoft.WindowsTerminal'
)

foreach ($pkg in $Packages) {
    Write-Host "==> winget install $pkg"
    if ($DryRun) { continue }
    # winget returns non-zero if already installed; that's fine.
    winget install --id $pkg --silent `
        --accept-source-agreements --accept-package-agreements 2>&1 |
        Tee-Object -Variable wingetOut | Out-Null
    if ($LASTEXITCODE -ne 0 -and ($wingetOut -notmatch 'already installed')) {
        Write-Warning "  winget exited $LASTEXITCODE for $pkg (continuing)"
    }
}

# Nerd Font for Windows Terminal. Installed via oh-my-posh's built-in font
# installer, which pulls from the official Nerd Fonts releases. The installer
# registers six family names (NF / NFM / NFP variants, with and without
# ligature-free NL versions). wt/settings.json references 'JetBrainsMono NFM'
# (Nerd Font Mono — strictly monospaced, best for terminal icon alignment).
if (-not $DryRun) {
    # Check both user and system scope. oh-my-posh registers names like
    # 'JetBrainsMono NFM Regular (TrueType)', so match the 'NF' shorthand.
    $alreadyInstalled = $false
    foreach ($scope in 'HKCU:', 'HKLM:') {
        try {
            $fontKey = Get-ItemProperty `
                -Path "$scope\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" `
                -ErrorAction SilentlyContinue
            if ($fontKey) {
                $match = $fontKey.PSObject.Properties |
                    Where-Object { $_.Name -like 'JetBrainsMono NF*' }
                if ($match) { $alreadyInstalled = $true; break }
            }
        } catch { }
    }

    if ($alreadyInstalled) {
        Write-Host '==> JetBrainsMono Nerd Font already installed, skipping'
    } elseif (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        Write-Host '==> Installing JetBrainsMono Nerd Font via oh-my-posh'
        # No --user flag: caused silent failures on some oh-my-posh versions.
        # Output is intentionally visible so any failure (network, picker) is diagnosable.
        oh-my-posh font install JetBrainsMono
        if ($LASTEXITCODE -ne 0) {
            Write-Warning '  Font install exited non-zero. Try manually: oh-my-posh font install JetBrainsMono'
        } else {
            Write-Host '  Font installed. Close ALL Windows Terminal windows and reopen for it to take effect.'
        }
    } else {
        Write-Warning '  oh-my-posh not on PATH yet; rerun bootstrap or install font manually'
    }
}

Write-Host "==> Prereqs done."
