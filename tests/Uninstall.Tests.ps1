#Requires -Version 7.0
# Pester tests for install/uninstall-windows.ps1 teardown.
# Run:  pwsh -c "Invoke-Pester tests/Uninstall.Tests.ps1"
# Works on any OS with pwsh 7+. Uses a non-dot fixture filename (profile.ps1) so
# Get-ChildItem finds it on Linux too, where leading-dot files are hidden.

BeforeAll {
    $root           = Split-Path -Parent $PSScriptRoot
    $script:Sut     = Join-Path $root 'install/uninstall-windows.ps1'
    $script:Symlink = Join-Path $root 'install/symlink-windows.ps1'
}

Describe 'uninstall-windows.ps1' {

    BeforeEach {
        $script:Sandbox  = Join-Path ([IO.Path]::GetTempPath()) ('unx-' + [Guid]::NewGuid().ToString('N').Substring(0, 12))
        $script:FakeHome = Join-Path $Sandbox 'home'
        $script:Dotfiles = Join-Path $Sandbox 'dotfiles'
        # 'pwsh' is in uninstall's module list; profile.ps1 is a non-dot file.
        New-Item -ItemType Directory -Force -Path $FakeHome, (Join-Path $Dotfiles 'pwsh'), (Join-Path $Dotfiles 'install') | Out-Null
        Set-Content -Path (Join-Path $Dotfiles 'pwsh/profile.ps1') -Value 'repo-profile'
        # uninstall-windows.ps1 delegates to symlink-windows.ps1 from the repo it
        # is pointed at — give the sandbox its own copy.
        Copy-Item $script:Symlink (Join-Path $Dotfiles 'install/symlink-windows.ps1')

        $script:Target = Join-Path $FakeHome 'profile.ps1'
    }

    AfterEach {
        if ($Sandbox -and (Test-Path $Sandbox)) { Remove-Item $Sandbox -Recurse -Force }
    }

    It 'removes a repo-owned link' {
        & $Symlink -Modules @('pwsh') -DotfilesPath $Dotfiles -TargetPath $FakeHome -NonInteractive | Out-Null
        (Get-Item $Target -Force).LinkType | Should -Be 'SymbolicLink'

        & $Sut -DotfilesPath $Dotfiles -TargetPath $FakeHome | Out-Null
        Test-Path $Target | Should -BeFalse
    }

    It 'never touches a real (non-linked) file' {
        Set-Content -Path $Target -Value 'mine'

        & $Sut -DotfilesPath $Dotfiles -TargetPath $FakeHome | Out-Null

        (Get-Item $Target -Force).LinkType | Should -BeNullOrEmpty
        Get-Content $Target | Should -Be 'mine'
    }

    It 'dry-run removes nothing' {
        & $Symlink -Modules @('pwsh') -DotfilesPath $Dotfiles -TargetPath $FakeHome -NonInteractive | Out-Null

        & $Sut -DryRun -DotfilesPath $Dotfiles -TargetPath $FakeHome | Out-Null

        (Get-Item $Target -Force).LinkType | Should -Be 'SymbolicLink'
    }
}
