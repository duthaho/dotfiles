#Requires -Version 7.0
# Pester tests for install/symlink-windows.ps1 conflict flow.
# Run:  pwsh -c "Invoke-Pester tests"
# Works on any OS with pwsh 7+ (symlink creation preflight only applies on Windows).

BeforeAll {
    $script:Sut = Join-Path (Split-Path -Parent $PSScriptRoot) 'install/symlink-windows.ps1'

    function Invoke-Sut {
        param([switch]$DryRun)
        # 6>&1 folds the Write-Host information stream into output for assertions
        & $script:Sut -Modules @('pwsh') -DotfilesPath $script:Dotfiles `
            -TargetPath $script:FakeHome -NonInteractive -DryRun:$DryRun 6>&1
    }

    # Interactive invocation (no -NonInteractive): the caller mocks Read-Host.
    function Invoke-SutInteractive {
        & $script:Sut -Modules @('pwsh') -DotfilesPath $script:Dotfiles `
            -TargetPath $script:FakeHome 6>&1
    }
}

Describe 'symlink-windows.ps1 conflict flow' {

    BeforeEach {
        $script:Sandbox  = Join-Path ([IO.Path]::GetTempPath()) ('sbx-' + [Guid]::NewGuid().ToString('N').Substring(0, 12))
        $script:FakeHome = Join-Path $Sandbox 'home'
        $script:Dotfiles = Join-Path $Sandbox 'dotfiles'
        New-Item -ItemType Directory -Force -Path $FakeHome, (Join-Path $Dotfiles 'pwsh/sub') | Out-Null
        Set-Content -Path (Join-Path $Dotfiles 'pwsh/profile.ps1') -Value 'repo-profile'
        Set-Content -Path (Join-Path $Dotfiles 'pwsh/sub/mod.ps1')  -Value 'repo-mod'
        $script:BackupRoot = Join-Path $FakeHome '.dotfiles-backup'
    }

    AfterEach {
        if ($Sandbox -and (Test-Path $Sandbox)) { Remove-Item $Sandbox -Recurse -Force }
        Remove-Variable -Name RhCalls, RhAnswers, RhI -Scope Global -ErrorAction SilentlyContinue
    }

    It 'sanity: clean target links whole module' {
        Invoke-Sut
        $link = Get-Item (Join-Path $FakeHome 'profile.ps1') -Force
        $link.LinkType | Should -Be 'SymbolicLink'
        Get-Content (Join-Path $FakeHome 'profile.ps1') | Should -Be 'repo-profile'
        Get-Content (Join-Path $FakeHome 'sub/mod.ps1')  | Should -Be 'repo-mod'
    }

    It 'real-file conflict: backed up with relative path, then linked, path printed' {
        New-Item -ItemType Directory -Force -Path (Join-Path $FakeHome 'sub') | Out-Null
        Set-Content -Path (Join-Path $FakeHome 'sub/mod.ps1') -Value 'home-mod'

        $out = Invoke-Sut | Out-String

        (Get-Item (Join-Path $FakeHome 'sub/mod.ps1') -Force).LinkType | Should -Be 'SymbolicLink'
        Get-Content (Join-Path $FakeHome 'sub/mod.ps1') | Should -Be 'repo-mod'

        $bdir = Get-ChildItem $BackupRoot -Directory | Select-Object -First 1
        Get-Content (Join-Path $bdir.FullName 'sub/mod.ps1') | Should -Be 'home-mod'
        $out | Should -Match '\.dotfiles-backup'
    }

    It 'foreign symlink: treated as conflict, backed up, never clobbered' {
        $foreignDest = Join-Path $Sandbox 'elsewhere.txt'
        Set-Content -Path $foreignDest -Value 'foreign-content'
        New-Item -ItemType SymbolicLink -Path (Join-Path $FakeHome 'profile.ps1') -Target $foreignDest | Out-Null

        Invoke-Sut

        # new link points into the repo
        Get-Content (Join-Path $FakeHome 'profile.ps1') | Should -Be 'repo-profile'
        # the old link was moved into backup, still pointing at its destination
        $bdir = Get-ChildItem $BackupRoot -Directory | Select-Object -First 1
        $moved = Get-Item (Join-Path $bdir.FullName 'profile.ps1') -Force
        $moved.LinkType | Should -Be 'SymbolicLink'
        # foreign destination untouched
        Get-Content $foreignDest | Should -Be 'foreign-content'
    }

    It 'ours-but-stale symlink: re-pointed silently, no backup made' {
        # link exists but points at another file inside the repo
        New-Item -ItemType SymbolicLink -Path (Join-Path $FakeHome 'profile.ps1') `
            -Target (Join-Path $Dotfiles 'pwsh/sub/mod.ps1') | Out-Null

        Invoke-Sut

        Get-Content (Join-Path $FakeHome 'profile.ps1') | Should -Be 'repo-profile'
        Test-Path $BackupRoot | Should -BeFalse
    }

    It 'already-correct link: skipped, no backup' {
        Invoke-Sut
        Invoke-Sut
        Test-Path $BackupRoot | Should -BeFalse
    }

    It 'two conflicting runs produce distinct backup dirs' {
        Set-Content -Path (Join-Path $FakeHome 'profile.ps1') -Value 'one'
        Invoke-Sut
        Remove-Item (Join-Path $FakeHome 'profile.ps1') -Force
        Set-Content -Path (Join-Path $FakeHome 'profile.ps1') -Value 'two'
        Invoke-Sut

        (Get-ChildItem $BackupRoot -Directory).Count | Should -Be 2
        $contents = Get-ChildItem $BackupRoot -Directory |
            ForEach-Object { Get-Content (Join-Path $_.FullName 'profile.ps1') } | Sort-Object
        $contents | Should -Be @('one', 'two')
    }

    It 'dry-run with conflict: reports plan, touches nothing' {
        Set-Content -Path (Join-Path $FakeHome 'profile.ps1') -Value 'home-profile'

        $out = Invoke-Sut -DryRun | Out-String

        $out | Should -Match 'would back up'
        Test-Path $BackupRoot | Should -BeFalse
        (Get-Item (Join-Path $FakeHome 'profile.ps1') -Force).LinkType | Should -BeNullOrEmpty
        Get-Content (Join-Path $FakeHome 'profile.ps1') | Should -Be 'home-profile'
    }

    # --- interactive prompt path (spec criterion 5: "same choices") ---
    # Read-Host is mocked to feed a scripted sequence of answers.

    It 'interactive skip: keeps file, no backup, links the rest of the module' {
        Set-Content -Path (Join-Path $FakeHome 'profile.ps1') -Value 'home-profile'
        Mock Read-Host { 's' }

        Invoke-SutInteractive

        (Get-Item (Join-Path $FakeHome 'profile.ps1') -Force).LinkType | Should -BeNullOrEmpty
        Get-Content (Join-Path $FakeHome 'profile.ps1') | Should -Be 'home-profile'
        Test-Path $BackupRoot | Should -BeFalse
        # sibling still linked
        Get-Content (Join-Path $FakeHome 'sub/mod.ps1') | Should -Be 'repo-mod'
    }

    It 'interactive backup: backs up then links' {
        Set-Content -Path (Join-Path $FakeHome 'profile.ps1') -Value 'home-profile'
        Mock Read-Host { 'b' }

        Invoke-SutInteractive

        Get-Content (Join-Path $FakeHome 'profile.ps1') | Should -Be 'repo-profile'
        $bdir = Get-ChildItem $BackupRoot -Directory | Select-Object -First 1
        Get-Content (Join-Path $bdir.FullName 'profile.ps1') | Should -Be 'home-profile'
    }

    It 'interactive backup-all: one A answer resolves every remaining conflict' {
        Set-Content -Path (Join-Path $FakeHome 'profile.ps1') -Value 'home-profile'
        New-Item -ItemType Directory -Force -Path (Join-Path $FakeHome 'sub') | Out-Null
        Set-Content -Path (Join-Path $FakeHome 'sub/mod.ps1') -Value 'home-mod'

        # A must be answered only ONCE; a second Read-Host call would return $null
        # and fail to resolve the second conflict. ($global: so the mock body sees it.)
        $global:RhCalls = 0
        Mock Read-Host { $global:RhCalls++; 'A' }

        Invoke-SutInteractive

        $global:RhCalls | Should -Be 1
        $bdir = Get-ChildItem $BackupRoot -Directory | Select-Object -First 1
        Get-Content (Join-Path $bdir.FullName 'profile.ps1') | Should -Be 'home-profile'
        Get-Content (Join-Path $bdir.FullName 'sub/mod.ps1')  | Should -Be 'home-mod'
        Get-Content (Join-Path $FakeHome 'profile.ps1') | Should -Be 'repo-profile'
        Get-Content (Join-Path $FakeHome 'sub/mod.ps1')  | Should -Be 'repo-mod'
    }

    It 'interactive invalid answer reprompts, then honors a valid one' {
        Set-Content -Path (Join-Path $FakeHome 'profile.ps1') -Value 'home-profile'
        $global:RhAnswers = @('x', 'b')
        $global:RhI = 0
        Mock Read-Host { $a = $global:RhAnswers[$global:RhI]; $global:RhI++; $a }

        Invoke-SutInteractive

        $global:RhI | Should -Be 2   # invalid consumed, then 'b'
        Get-Content (Join-Path $FakeHome 'profile.ps1') | Should -Be 'repo-profile'
    }

    It 'interactive dry-run reports it would prompt, changes nothing' {
        Set-Content -Path (Join-Path $FakeHome 'profile.ps1') -Value 'home-profile'
        Mock Read-Host { throw 'dry-run must not prompt' }

        $out = & $script:Sut -Modules @('pwsh') -DotfilesPath $script:Dotfiles `
            -TargetPath $script:FakeHome -DryRun 6>&1 | Out-String

        $out | Should -Match 'would prompt'
        Test-Path $BackupRoot | Should -BeFalse
        Get-Content (Join-Path $FakeHome 'profile.ps1') | Should -Be 'home-profile'
    }
}
