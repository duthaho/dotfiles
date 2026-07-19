#!/usr/bin/env bats
# Tests for install/fork-safety-scan.sh

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
  SBX="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/fsx.XXXXXX")"
  export HOME="$SBX/home"; mkdir -p "$HOME"
  export DOTFILES="$SBX/repo"; mkdir -p "$DOTFILES/install"
  cp "$REPO_ROOT/install/fork-safety-scan.sh" "$DOTFILES/install/fork-safety-scan.sh"
  SCAN="$DOTFILES/install/fork-safety-scan.sh"
  git -C "$DOTFILES" init -q
  git -C "$DOTFILES" config user.name t
  git -C "$DOTFILES" config user.email t@t
}
teardown() { [[ -n "${SBX:-}" && -d "$SBX" ]] && command rm -rf "$SBX"; return 0; }

# Stage everything, then scan tracked files.
scan() { git -C "$DOTFILES" add -A >/dev/null 2>&1; "$SCAN" "$@"; }

@test "clean repo passes" {
  echo "just some ordinary prose" > "$DOTFILES/README.md"
  run scan
  [ "$status" -eq 0 ]
  [[ "$output" == *"no leaked identity"* ]]
}

@test "a real email address is flagged" {
  echo "reach me at jane.doe@gmail.com anytime" > "$DOTFILES/notes.md"
  run scan
  [ "$status" -eq 1 ]
  [[ "$output" == *"secret/PII"* ]]
}

@test "example.* and *.invalid placeholders are allowed" {
  printf 'ci@example.invalid\nyou@example.com\nname@host\n' > "$DOTFILES/notes.md"
  run scan
  [ "$status" -eq 0 ]
}

@test "a GitHub token is flagged" {
  printf 'GITHUB_TOKEN=ghp_%s\n' "$(printf 'a%.0s' {1..36})" > "$DOTFILES/creds.env"
  run scan
  [ "$status" -eq 1 ]
}

@test "a private-key header is flagged" {
  echo "-----BEGIN OPENSSH PRIVATE KEY-----" > "$DOTFILES/id_ed25519"
  run scan
  [ "$status" -eq 1 ]
}

@test "identity email from ~/.gitconfig.local is flagged even if its domain looks benign" {
  # me@example.com would be allowlisted as a generic placeholder — but as YOUR
  # sidecar identity it must still be caught. Proves the identity path, not the
  # generic email path.
  printf '[user]\n\tname = duthaho\n\temail = me@example.com\n' > "$HOME/.gitconfig.local"
  echo "signed-off-by: me@example.com" > "$DOTFILES/CONTRIBUTORS.md"
  run scan
  [ "$status" -eq 1 ]
  [[ "$output" == *"identity"* ]]
}

@test "a git user.name matching a handle in repo URLs is NOT flagged" {
  # Regression: name must not match — github.com/duthaho/... is public attribution.
  printf '[user]\n\tname = duthaho\n\temail = me@example.com\n' > "$HOME/.gitconfig.local"
  echo "clone https://github.com/duthaho/dotfiles" > "$DOTFILES/README.md"
  echo "Copyright (c) 2026 duthaho" > "$DOTFILES/LICENSE"
  run scan
  [ "$status" -eq 0 ]
}

@test "excluded paths (tests/, out/, scanner) are not scanned" {
  mkdir -p "$DOTFILES/tests" "$DOTFILES/out"
  echo "leak@gmail.com"  > "$DOTFILES/tests/x"
  echo "leak2@gmail.com" > "$DOTFILES/out/y"
  run scan
  [ "$status" -eq 0 ]
}

@test "--staged only sees staged additions" {
  echo "clean" > "$DOTFILES/a.md"
  git -C "$DOTFILES" add -A >/dev/null 2>&1
  git -C "$DOTFILES" commit -qm init

  # unstaged leak — invisible to --staged
  echo "boss@company.com" > "$DOTFILES/b.md"
  run "$SCAN" --staged
  [ "$status" -eq 0 ]

  # once staged, it's caught
  git -C "$DOTFILES" add b.md
  run "$SCAN" --staged
  [ "$status" -eq 1 ]
}
