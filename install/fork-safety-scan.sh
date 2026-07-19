#!/usr/bin/env bash
# fork-safety-scan.sh — guard the fork-safety moat.
#
# The repo's promise is that it carries NO personal info: identity lives only in
# gitignored *.local sidecars, so anyone can fork it clean. This scanner enforces
# that promise mechanically. It fails (exit 1) if a tracked/staged file contains:
#   - your actual git identity (name/email read from ~/.gitconfig.local), or
#   - a credential shape: private key, GitHub/Slack token, AWS key, or a
#     real-looking email address (example.* / *.invalid placeholders are allowed).
#
# Self-contained: no gitleaks/trufflehog dependency, so it runs identically on
# every platform the repo targets. Deliberately narrow — an identity/secret
# guard, not a general secret manager.
#
# Usage:
#   fork-safety-scan.sh            # scan all git-tracked files
#   fork-safety-scan.sh --staged   # scan only staged additions (pre-commit hook)
#
# Exit: 0 clean, 1 findings, 2 usage error.

set -uo pipefail

DOTFILES="${DOTFILES:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$DOTFILES"

STAGED=0
for arg in "$@"; do
  case "$arg" in
    --staged) STAGED=1 ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "ERROR: unknown flag: $arg" >&2; exit 2 ;;
  esac
done

# Paths that legitimately contain pattern-like text: this scanner and its tests
# hold the regexes; out/ holds research notes with example addresses. Skipping
# them avoids self-flagging.
is_excluded() { # $1 = repo-relative path
  case "$1" in
    install/fork-safety-scan.sh|install/fork-safety-scan.ps1) return 0 ;;
    .githooks/*)  return 0 ;;
    tests/*)      return 0 ;;
    out/*)        return 0 ;;
  esac
  return 1
}

# Credential/PII shapes. The email pattern is last; its benign placeholders are
# filtered by ALLOW below so example addresses in docs don't trip the guard.
SECRET_PATTERNS=(
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'gh[oprsu]_[A-Za-z0-9]{36}'
  'github_pat_[A-Za-z0-9_]{22,}'
  'AKIA[0-9A-Z]{16}'
  'xox[baprs]-[A-Za-z0-9-]{10,}'
  '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
)
# Benign matches to ignore (documentation/CI placeholders, not real identity).
ALLOW='example\.(com|org|net|invalid)|@example|\.invalid|noreply|you@|user@host|name@host'

# Your email, read live from the sidecar — the one identity token that never
# legitimately appears in a fork-safe repo. (Name is deliberately NOT matched:
# a git user.name is often a handle that shows up in the repo's own URLs and
# LICENSE copyright, which is public attribution, not a leak.) Empty when the
# sidecar is absent (CI, fresh clone); the generic patterns still run.
IDENTITY_LITERALS=()
# FORK_SAFETY_SIDECAR overrides the sidecar path (test isolation); default is the
# real ~/.gitconfig.local.
LOCAL_GC="${FORK_SAFETY_SIDECAR:-$HOME/.gitconfig.local}"
if [[ -f "$LOCAL_GC" ]]; then
  gc_email="$(git config --file "$LOCAL_GC" --get user.email 2>/dev/null || true)"
  [[ -n "$gc_email" ]] && IDENTITY_LITERALS+=("$gc_email")
fi

FINDINGS=0

report() { # $1 = file, $2 = kind, $3 = "lineno:content"
  echo "  ✗ $2  $1:${3%%:*}"
  echo "      ${3#*:}"
  FINDINGS=$((FINDINGS + 1))
}

scan_file() { # $1 = repo-relative path
  local f="$1" hit lit pat
  [[ -f "$f" ]] || return 0

  # Exact personal identity (literal match, whole file).
  for lit in ${IDENTITY_LITERALS[@]+"${IDENTITY_LITERALS[@]}"}; do
    [[ -z "$lit" ]] && continue
    while IFS= read -r hit; do
      report "$f" "identity " "$hit"
    done < <(grep -nIF -- "$lit" "$f" 2>/dev/null || true)
  done

  # Credential shapes + real emails.
  for pat in "${SECRET_PATTERNS[@]}"; do
    while IFS= read -r hit; do
      # Drop benign placeholder matches.
      printf '%s\n' "${hit#*:}" | grep -Eiq "$ALLOW" && continue
      report "$f" "secret/PII" "$hit"
    done < <(grep -nIE -- "$pat" "$f" 2>/dev/null || true)
  done
}

# Collect the file list (NUL-safe) without mapfile — macOS ships bash 3.2.
if [[ $STAGED -eq 1 ]]; then
  list_cmd() { git diff --cached --name-only --diff-filter=ACM -z; }
else
  list_cmd() { git ls-files -z; }
fi

while IFS= read -r -d '' path; do
  is_excluded "$path" && continue
  scan_file "$path"
done < <(list_cmd)

echo ""
if [[ $FINDINGS -gt 0 ]]; then
  echo "✗ fork-safety: $FINDINGS potential leak(s) found."
  echo "  Personal info belongs in gitignored *.local sidecars, never the repo."
  exit 1
fi
echo "✓ fork-safety: no leaked identity or secrets in scanned files."
