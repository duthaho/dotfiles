#Requires -Version 7.0
# Pester tests for install/fork-safety-scan.ps1
# Run:  pwsh -c "Invoke-Pester tests/ForkSafety.Tests.ps1"
# The identity-from-sidecar path is covered by tests/fork-safety.bats (overriding
# $HOME is unreliable in-process on Windows); here we exercise the shared core.

BeforeAll {
    $script:Sut = Join-Path (Split-Path -Parent $PSScriptRoot) 'install/fork-safety-scan.ps1'

    # Stage everything, run the scanner, return its exit code.
    function Invoke-Scan {
        param([switch]$Staged)
        Push-Location $script:Repo
        try { git add -A 2>$null } finally { Pop-Location }
        & $script:Sut -DotfilesPath $script:Repo -Staged:$Staged | Out-Null
        $LASTEXITCODE
    }
}

Describe 'fork-safety-scan.ps1' {

    BeforeEach {
        $script:Sandbox = Join-Path ([IO.Path]::GetTempPath()) ('fss-' + [Guid]::NewGuid().ToString('N').Substring(0, 12))
        $script:Repo    = Join-Path $Sandbox 'repo'
        New-Item -ItemType Directory -Force -Path (Join-Path $Repo 'install') | Out-Null
        Copy-Item $script:Sut (Join-Path $Repo 'install/fork-safety-scan.ps1')
        Push-Location $Repo
        try {
            git init -q
            git config user.name  t
            git config user.email t@t
        } finally { Pop-Location }
    }

    AfterEach {
        if ($Sandbox -and (Test-Path $Sandbox)) { Remove-Item $Sandbox -Recurse -Force }
    }

    It 'clean repo passes' {
        Set-Content (Join-Path $Repo 'README.md') 'just some ordinary prose'
        Invoke-Scan | Should -Be 0
    }

    It 'flags a real email address' {
        Set-Content (Join-Path $Repo 'notes.md') 'reach me at jane.doe@gmail.com anytime'
        Invoke-Scan | Should -Be 1
    }

    It 'allows example.* / *.invalid placeholders' {
        Set-Content (Join-Path $Repo 'notes.md') "ci@example.invalid`nyou@example.com"
        Invoke-Scan | Should -Be 0
    }

    It 'flags a GitHub token' {
        Set-Content (Join-Path $Repo 'creds.env') ('GITHUB_TOKEN=ghp_' + ('a' * 36))
        Invoke-Scan | Should -Be 1
    }

    It 'flags a private-key header' {
        Set-Content (Join-Path $Repo 'id_ed25519') '-----BEGIN OPENSSH PRIVATE KEY-----'
        Invoke-Scan | Should -Be 1
    }

    It 'ignores excluded paths (tests/, out/)' {
        New-Item -ItemType Directory -Force -Path (Join-Path $Repo 'tests'), (Join-Path $Repo 'out') | Out-Null
        Set-Content (Join-Path $Repo 'tests/x') 'leak@gmail.com'
        Set-Content (Join-Path $Repo 'out/y')   'leak2@gmail.com'
        Invoke-Scan | Should -Be 0
    }

    It '--staged only sees staged additions' {
        Set-Content (Join-Path $Repo 'a.md') 'clean'
        Push-Location $Repo
        try { git add -A 2>$null; git commit -qm init } finally { Pop-Location }

        Set-Content (Join-Path $Repo 'b.md') 'boss@company.com'   # unstaged leak
        & $script:Sut -DotfilesPath $Repo -Staged | Out-Null
        $LASTEXITCODE | Should -Be 0

        Push-Location $Repo
        try { git add b.md } finally { Pop-Location }
        & $script:Sut -DotfilesPath $Repo -Staged | Out-Null
        $LASTEXITCODE | Should -Be 1
    }
}
