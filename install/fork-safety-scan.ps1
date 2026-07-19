#Requires -Version 7.0
<#
.SYNOPSIS
    Guard the fork-safety moat (Windows twin of fork-safety-scan.sh).

.DESCRIPTION
    Fails (exit 1) if a tracked/staged file leaks personal identity (name/email
    from ~/.gitconfig.local) or a credential shape (private key, GitHub/Slack
    token, AWS key, real-looking email). example.* / *.invalid placeholders are
    allowed. Self-contained — no external scanner dependency.

.PARAMETER Staged
    Scan only staged additions (pre-commit hook). Default: all tracked files.

.PARAMETER DotfilesPath
    Override the repo path (defaults to parent of this script's dir).
#>

[CmdletBinding()]
param(
    [switch]$Staged,
    [string]$DotfilesPath
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

if (-not $DotfilesPath) {
    $DotfilesPath = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
}
Push-Location $DotfilesPath
try {
    # Paths that legitimately hold pattern-like text.
    $excluded = {
        param($p)
        $p -in @('install/fork-safety-scan.sh', 'install/fork-safety-scan.ps1') -or
        $p -like '.githooks/*' -or $p -like 'tests/*' -or $p -like 'out/*'
    }

    $secretPatterns = @(
        '-----BEGIN [A-Z ]*PRIVATE KEY-----'
        'gh[oprsu]_[A-Za-z0-9]{36}'
        'github_pat_[A-Za-z0-9_]{22,}'
        'AKIA[0-9A-Z]{16}'
        'xox[baprs]-[A-Za-z0-9-]{10,}'
        '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
    )
    $allow = 'example\.(com|org|net|invalid)|@example|\.invalid|noreply|you@|user@host|name@host'

    # Your email from the sidecar — the one identity token that never
    # legitimately appears in a fork-safe repo. Name is deliberately NOT matched
    # (a git user.name is often a handle that shows up in the repo's own URLs and
    # LICENSE copyright — public attribution, not a leak). Empty on CI / fresh clone.
    $identityLiterals = @()
    $localGc = Join-Path $HOME '.gitconfig.local'
    if (Test-Path $localGc) {
        $e = (& git config --file $localGc --get user.email) 2>$null
        if ($e) { $identityLiterals += [regex]::Escape($e) }
    }

    $findings = 0
    function Write-Finding($file, $kind, $lineNo, $text) {
        Write-Host "  x $kind  ${file}:$lineNo"
        Write-Host "      $text"
        $script:findings++
    }

    if ($Staged) {
        $files = & git diff --cached --name-only --diff-filter=ACM
    } else {
        $files = & git ls-files
    }

    foreach ($f in $files) {
        if (-not $f) { continue }
        if (& $excluded $f) { continue }
        if (-not (Test-Path $f -PathType Leaf)) { continue }

        # Identity: exact (escaped) literal match.
        foreach ($lit in $identityLiterals) {
            Select-String -Path $f -Pattern $lit -AllMatches -ErrorAction SilentlyContinue |
                ForEach-Object { Write-Finding $f 'identity ' $_.LineNumber $_.Line.Trim() }
        }
        # Credential shapes + real emails, minus benign placeholders.
        foreach ($pat in $secretPatterns) {
            Select-String -Path $f -Pattern $pat -AllMatches -ErrorAction SilentlyContinue |
                Where-Object { $_.Line -notmatch $allow } |
                ForEach-Object { Write-Finding $f 'secret/PII' $_.LineNumber $_.Line.Trim() }
        }
    }

    Write-Host ''
    if ($findings -gt 0) {
        Write-Host "x fork-safety: $findings potential leak(s) found."
        Write-Host '  Personal info belongs in gitignored *.local sidecars, never the repo.'
        exit 1
    }
    Write-Host 'OK fork-safety: no leaked identity or secrets in scanned files.'
    exit 0
} finally {
    Pop-Location
}
