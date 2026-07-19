#Requires -Version 7.0
# Pester tests for install/plan-windows.ps1 symlink drift classification.
# No winget manifest in the sandbox → the packages section skips, so exit codes
# reflect symlink state alone. Uses non-dot fixture names (Get-ChildItem hides
# dot-files on Linux).

BeforeAll {
    $root           = Split-Path -Parent $PSScriptRoot
    $script:Sut     = Join-Path $root 'install/plan-windows.ps1'
    $script:Symlink = Join-Path $root 'install/symlink-windows.ps1'
}

Describe 'plan-windows.ps1' {

    BeforeEach {
        $script:Sandbox  = Join-Path ([IO.Path]::GetTempPath()) ('plw-' + [Guid]::NewGuid().ToString('N').Substring(0, 12))
        $script:FakeHome = Join-Path $Sandbox 'home'
        $script:Dotfiles = Join-Path $Sandbox 'dotfiles'
        New-Item -ItemType Directory -Force -Path $FakeHome, (Join-Path $Dotfiles 'pwsh/sub') | Out-Null
        Set-Content -Path (Join-Path $Dotfiles 'pwsh/profile.ps1') -Value 'repo-profile'
        Set-Content -Path (Join-Path $Dotfiles 'pwsh/sub/mod.ps1')  -Value 'repo-mod'
    }

    AfterEach {
        if ($Sandbox -and (Test-Path $Sandbox)) { Remove-Item $Sandbox -Recurse -Force }
    }

    It 'reports an in-sync module as linked (exit 0)' {
        & $Symlink -Modules @('pwsh') -DotfilesPath $Dotfiles -TargetPath $FakeHome -NonInteractive | Out-Null
        $out = & $Sut -DotfilesPath $Dotfiles -TargetPath $FakeHome 6>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $out | Should -Match 'pwsh \(2 linked\)'
    }

    It 'reports missing targets as drift (exit 2)' {
        $out = & $Sut -DotfilesPath $Dotfiles -TargetPath $FakeHome 6>&1 | Out-String
        $LASTEXITCODE | Should -Be 2
        $out | Should -Match 'would link'
    }

    It 'classifies a real file at a target as a conflict (exit 2)' {
        New-Item -ItemType Directory -Force -Path (Join-Path $FakeHome 'sub') | Out-Null
        Set-Content -Path (Join-Path $FakeHome 'profile.ps1') -Value 'mine'
        $out = & $Sut -DotfilesPath $Dotfiles -TargetPath $FakeHome 6>&1 | Out-String
        $LASTEXITCODE | Should -Be 2
        $out | Should -Match 'would back up'
    }
}
