#!/usr/bin/env bats
# Tests for install/plan.sh symlink drift classification.
# Reuses the stow fixture; the package manifests are emptied so the packages
# section adds no drift and exit codes reflect symlink state alone.

load helpers/setup

setup() {
  make_sandbox
  mkdir -p "$DOTFILES/install/packages"
  cp "$REPO_ROOT/install/detect-os.sh" "$DOTFILES/install/detect-os.sh"
  : > "$DOTFILES/install/packages/Brewfile"          # empty → satisfied
  : > "$DOTFILES/install/packages/apt-packages.txt"  # empty → 0/0
  : > "$DOTFILES/install/packages/dnf-packages.txt"
  PLAN="$REPO_ROOT/install/plan.sh"
}
teardown() { teardown_sandbox; }

@test "an in-sync module reports as linked" {
  run "$SUT" zsh
  [ "$status" -eq 0 ]
  run "$PLAN"
  [[ "$output" == *"zsh (2 linked)"* ]]
}

@test "missing targets report drift and exit 2" {
  run "$PLAN"
  [ "$status" -eq 2 ]
  [[ "$output" == *"would link"* ]]
  [[ "$output" == *"drifted area"* ]]
}

@test "a real file at a target is classified as a conflict" {
  echo "mine" > "$HOME/.zshrc"
  run "$PLAN"
  [ "$status" -eq 2 ]
  [[ "$output" == *"would back up + link"* ]]
}

@test "a folded-directory link counts as linked, not drift" {
  # Empty HOME → stow folds ~/.config; the nested file must still read as linked.
  run "$SUT" zsh
  [ "$status" -eq 0 ]
  run "$PLAN"
  # zsh has .zshrc + .config/deep/file.conf; both linked via the fold
  [[ "$output" == *"zsh (2 linked)"* ]]
}

@test "a fully-stowed repo is in sync (exit 0)" {
  [[ "$(uname -s)" == "Darwin" ]] && skip "brew bundle check on empty Brewfile not asserted on macOS"
  mkdir -p "$HOME/.config/kitty"   # keep kitty.conf a file-level link
  run "$SUT" zsh
  [ "$status" -eq 0 ]
  run "$SUT" kitty
  [ "$status" -eq 0 ]
  run "$PLAN"
  [ "$status" -eq 0 ]
  [[ "$output" == *"In sync"* ]]
}
