#Requires -Version 7.0
<#
.SYNOPSIS
    Prompt for git identity; write gitignored sidecars.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$GitConfigLocal = Join-Path $HOME '.gitconfig.local'
$PwshLocal      = Join-Path $HOME '.pwsh.local.ps1'

if ((Test-Path $GitConfigLocal) -and (Test-Path $PwshLocal)) {
    Write-Host "==> Identity sidecars already present, skipping"
    return
}

Write-Host "==> Seeding identity (writes to ~\.gitconfig.local and ~\.pwsh.local.ps1)"

$GitName  = Read-Host 'Git user.name'
$GitEmail = Read-Host 'Git user.email'
$GhHandle = Read-Host 'GitHub handle (optional, press enter to skip)'

if (-not (Test-Path $GitConfigLocal)) {
    $content = @"
[user]
    name = $GitName
    email = $GitEmail
"@
    if ($GhHandle) {
        $content += @"

[github]
    user = $GhHandle
"@
    }
    Set-Content -Path $GitConfigLocal -Value $content -NoNewline:$false
    Write-Host "==> Wrote $GitConfigLocal"
}

if (-not (Test-Path $PwshLocal)) {
    Set-Content -Path $PwshLocal `
        -Value "# Personal/machine-local PowerShell config. Add aliases, env vars, paths."
    Write-Host "==> Wrote $PwshLocal"
}
