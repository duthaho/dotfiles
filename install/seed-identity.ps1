#Requires -Version 7.0
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

if ($env:NON_INTERACTIVE) {
    if (-not $env:GIT_USER_NAME -or -not $env:GIT_USER_EMAIL) {
        Write-Error 'NON_INTERACTIVE set but GIT_USER_NAME or GIT_USER_EMAIL missing'
        exit 1
    }
    $GitName  = $env:GIT_USER_NAME
    $GitEmail = $env:GIT_USER_EMAIL
    $GhHandle = if ($env:GH_HANDLE) { $env:GH_HANDLE } else { '' }
    Write-Host '  (using GIT_USER_NAME / GIT_USER_EMAIL from environment)'
} else {
    $GitName  = Read-Host 'Git user.name'
    $GitEmail = Read-Host 'Git user.email'
    $GhHandle = Read-Host 'GitHub handle (optional, press enter to skip)'
}

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
