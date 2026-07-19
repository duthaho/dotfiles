#!/usr/bin/env bats
# Tests for install/update.sh — package-manifest change detection + doctor close.
# Uses a bare "remote" and a working clone; stows/doctor/bootstrap are stubbed so
# the assertions target update.sh's own logic.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
  SBX="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/upd.XXXXXX")"
  export HOME="$SBX/home"; mkdir -p "$HOME"
  REMOTE="$SBX/remote.git"; REPO="$SBX/repo"

  git init -q --bare -b main "$REMOTE"
  git clone -q "$REMOTE" "$REPO"
  git -C "$REPO" config user.email t@t
  git -C "$REPO" config user.name  t
  git -C "$REPO" checkout -q -b main 2>/dev/null || true

  mkdir -p "$REPO/install/packages" "$REPO/zsh"
  cp "$REPO_ROOT/install/update.sh"    "$REPO/install/update.sh"
  cp "$REPO_ROOT/install/prompt-yn.sh" "$REPO/install/prompt-yn.sh"
  # Stubs keep the test focused on update.sh.
  printf '#!/usr/bin/env bash\necho "STOW $*"\n'       > "$REPO/install/stow-modules.sh"
  printf '#!/usr/bin/env bash\necho "DOCTOR-RAN"\n'    > "$REPO/doctor.sh"
  printf '#!/usr/bin/env bash\necho "BOOTSTRAP-RAN"\n' > "$REPO/bootstrap.sh"
  chmod +x "$REPO/install/"*.sh "$REPO/doctor.sh" "$REPO/bootstrap.sh"
  echo "probe"   > "$REPO/zsh/.probe"
  echo "ripgrep" > "$REPO/install/packages/apt-packages.txt"

  git -C "$REPO" add -A
  git -C "$REPO" commit -qm init
  git -C "$REPO" push -qu origin main

  UPDATE="$REPO/install/update.sh"
}
teardown() { [[ -n "${SBX:-}" && -d "$SBX" ]] && command rm -rf "$SBX"; return 0; }

# Push a commit to the remote that appends to a file (simulating an upstream pull).
push_upstream() { # $1 = repo-relative path, $2 = line to append
  local up="$SBX/up"
  command rm -rf "$up"
  git clone -q "$REMOTE" "$up"
  git -C "$up" config user.email t@t
  git -C "$up" config user.name  t
  echo "$2" >> "$up/$1"
  git -C "$up" commit -qam "upstream: $1"
  git -C "$up" push -q origin main
}

run_update() { DOTFILES="$REPO" "$UPDATE" "$@"; }

@test "package-manifest change triggers a notice (non-interactive)" {
  push_upstream install/packages/apt-packages.txt "fd-find"
  run env DOTFILES="$REPO" NON_INTERACTIVE=1 "$UPDATE" --no-doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"Package manifests changed"* ]]
  [[ "$output" == *"apt-packages.txt"* ]]
  [[ "$output" == *"Run: dot bootstrap"* ]]
}

@test "a non-package change does NOT trigger the notice" {
  push_upstream zsh/.probe "more"
  run env DOTFILES="$REPO" NON_INTERACTIVE=1 "$UPDATE" --no-doctor
  [ "$status" -eq 0 ]
  [[ "$output" != *"Package manifests changed"* ]]
  [[ "$output" == *"STOW"* ]]   # re-stow still ran
}

@test "no upstream change reports already up to date" {
  run env DOTFILES="$REPO" NON_INTERACTIVE=1 "$UPDATE" --no-doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already up to date"* ]]
  [[ "$output" != *"Package manifests changed"* ]]
}

@test "doctor runs by default and --no-doctor skips it" {
  run env DOTFILES="$REPO" NON_INTERACTIVE=1 "$UPDATE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DOCTOR-RAN"* ]]

  run env DOTFILES="$REPO" NON_INTERACTIVE=1 "$UPDATE" --no-doctor
  [ "$status" -eq 0 ]
  [[ "$output" != *"DOCTOR-RAN"* ]]
}

@test "interactive accept runs bootstrap" {
  push_upstream install/packages/apt-packages.txt "fd-find"
  run bash -c "printf 'y\n' | DOT_UPDATE_FORCE_INTERACTIVE=1 DOTFILES='$REPO' '$UPDATE' --no-doctor"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BOOTSTRAP-RAN"* ]]
}

@test "interactive decline skips bootstrap" {
  push_upstream install/packages/apt-packages.txt "fd-find"
  run bash -c "printf 'n\n' | DOT_UPDATE_FORCE_INTERACTIVE=1 DOTFILES='$REPO' '$UPDATE' --no-doctor"
  [ "$status" -eq 0 ]
  [[ "$output" != *"BOOTSTRAP-RAN"* ]]
  [[ "$output" == *"Skipped"* ]]
}
