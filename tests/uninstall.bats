#!/usr/bin/env bats
# Tests for install/uninstall.sh wholesale teardown.

load helpers/setup

setup() {
  make_sandbox
  # uninstall.sh keys off $DOTFILES; run the real script against the fixture repo.
  UNINST="$REPO_ROOT/install/uninstall.sh"
}
teardown() { teardown_sandbox; }

@test "uninstall removes a repo-owned symlink" {
  run "$SUT" zsh
  [ "$status" -eq 0 ]
  [ -L "$HOME/.zshrc" ]

  run "$UNINST"
  [ "$status" -eq 0 ]
  [ ! -L "$HOME/.zshrc" ]
  [[ "$output" == *"Uninstall complete"* ]]
}

@test "uninstall removes a folded-directory link (nested config)" {
  # Empty HOME → stow folds ~/.config into a single symlink into the repo.
  run "$SUT" zsh
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.config/deep/file.conf")" = "repo-deepconf" ]

  run "$UNINST"
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.config/deep/file.conf" ]   # the folded link is gone
}

@test "uninstall never touches a real (non-linked) file" {
  echo "mine" > "$HOME/.zshrc"

  run "$UNINST"
  [ "$status" -eq 0 ]
  [ -f "$HOME/.zshrc" ]
  [ ! -L "$HOME/.zshrc" ]
  [ "$(cat "$HOME/.zshrc")" = "mine" ]
}

@test "dry-run removes nothing" {
  run "$SUT" zsh
  [ -L "$HOME/.zshrc" ]

  run "$UNINST" --dry-run
  [ "$status" -eq 0 ]
  [ -L "$HOME/.zshrc" ]
  [[ "$output" == *"Dry run complete"* ]]
}

@test "removes the dot shim only when it links into the repo" {
  mkdir -p "$HOME/.local/bin"
  ln -s "$DOTFILES/bin/dot" "$HOME/.local/bin/dot"   # points into repo (dangling ok)
  ln -s /usr/bin/true       "$HOME/.local/bin/other" # foreign — must survive

  run "$UNINST"
  [ "$status" -eq 0 ]
  [ ! -L "$HOME/.local/bin/dot" ]
  [ -L "$HOME/.local/bin/other" ]
}

@test "prints the newest backup dir when backups exist" {
  mkdir -p "$HOME/.dotfiles-backup/20260101-000000"
  echo x > "$HOME/.dotfiles-backup/20260101-000000/.zshrc"

  run "$UNINST"
  [ "$status" -eq 0 ]
  [[ "$output" == *".dotfiles-backup/20260101-000000"* ]]
}
