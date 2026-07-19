#Requires -Version 7.0
# Pester tests for install/update-windows.ps1 — manifest change detection.
# Bare "remote" + working clone; symlink/doctor/bootstrap stubbed in the fixture.

BeforeAll {
    $script:Sut = Join-Path (Split-Path -Parent $PSScriptRoot) 'install/update-windows.ps1'

    # Push a commit to the remote appending a line to a file.
    function Push-Upstream {
        param([string]$RelPath, [string]$Line)
        $up = Join-Path $script:Sandbox 'up'
        if (Test-Path $up) { Remove-Item $up -Recurse -Force }
        & git clone -q $script:Remote $up
        Push-Location $up
        try {
            & git config user.email t@t
            & git config user.name  t
            Add-Content -Path $RelPath -Value $Line
            & git commit -qam upstream
            & git push -q origin main
        } finally { Pop-Location }
    }
}

Describe 'update-windows.ps1' {

    BeforeEach {
        $script:Sandbox = Join-Path ([IO.Path]::GetTempPath()) ('udw-' + [Guid]::NewGuid().ToString('N').Substring(0, 12))
        $script:Remote  = Join-Path $Sandbox 'remote.git'
        $script:Repo    = Join-Path $Sandbox 'repo'
        New-Item -ItemType Directory -Force -Path $Sandbox | Out-Null

        & git init -q --bare -b main $Remote
        & git clone -q $Remote $Repo
        Push-Location $Repo
        try {
            & git config user.email t@t
            & git config user.name  t
            New-Item -ItemType Directory -Force -Path 'install/packages', 'pwsh' | Out-Null
            Set-Content 'install/symlink-windows.ps1' @'
param([string[]]$Modules, [string]$DotfilesPath)
Write-Host "STOW"
'@
            Set-Content 'doctor.ps1'    'Write-Host "DOCTOR-RAN"'
            Set-Content 'bootstrap.ps1' 'Write-Host "BOOTSTRAP-RAN"'
            Set-Content 'install/packages/winget-packages.json' '{ "packages": ["A"] }'
            Set-Content 'pwsh/profile.ps1' 'x'
            & git add -A
            & git commit -qm init
            & git push -qu origin main
        } finally { Pop-Location }
    }

    AfterEach {
        if ($Sandbox -and (Test-Path $Sandbox)) { Remove-Item $Sandbox -Recurse -Force }
    }

    It 'flags a package-manifest change (non-interactive)' {
        Push-Upstream 'install/packages/winget-packages.json' '  "note": true'
        $out = & $Sut -DotfilesPath $Repo -NonInteractive -NoDoctor 6>&1 | Out-String
        $out | Should -Match 'Package manifests changed'
        $out | Should -Match 'Run: dot bootstrap'
    }

    It 'does not flag a non-package change' {
        Push-Upstream 'pwsh/profile.ps1' 'more'
        $out = & $Sut -DotfilesPath $Repo -NonInteractive -NoDoctor 6>&1 | Out-String
        $out | Should -Not -Match 'Package manifests changed'
        $out | Should -Match 'STOW'
    }

    It 'reports already up to date when nothing changed' {
        $out = & $Sut -DotfilesPath $Repo -NonInteractive -NoDoctor 6>&1 | Out-String
        $out | Should -Match 'Already up to date'
    }

    It 'runs doctor by default, skips it with -NoDoctor' {
        (& $Sut -DotfilesPath $Repo -NonInteractive 6>&1 | Out-String) | Should -Match 'DOCTOR-RAN'
        (& $Sut -DotfilesPath $Repo -NonInteractive -NoDoctor 6>&1 | Out-String) | Should -Not -Match 'DOCTOR-RAN'
    }

    It 'interactive accept runs bootstrap' {
        Push-Upstream 'install/packages/winget-packages.json' '  "note": true'
        Mock Read-Host { 'y' }
        $out = & $Sut -DotfilesPath $Repo -NoDoctor 6>&1 | Out-String
        $out | Should -Match 'BOOTSTRAP-RAN'
    }

    It 'interactive decline skips bootstrap' {
        Push-Upstream 'install/packages/winget-packages.json' '  "note": true'
        Mock Read-Host { 'n' }
        $out = & $Sut -DotfilesPath $Repo -NoDoctor 6>&1 | Out-String
        $out | Should -Not -Match 'BOOTSTRAP-RAN'
        $out | Should -Match 'Skipped'
    }
}
