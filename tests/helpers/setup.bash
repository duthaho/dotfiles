# setup.bash — shared bats fixtures for stow-modules tests.
#
# Provides:
#   make_sandbox   — temp $HOME + temp $DOTFILES containing a fixture module
#                    'zsh' (top-level .zshrc + nested .config/deep/file.conf),
#                    initialized as a git repo so "repo stays clean" is testable.
#   teardown_sandbox — removes everything.
#
# Tests run the real script: "$SUT" (path to install/stow-modules.sh).

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SUT="$REPO_ROOT/install/stow-modules.sh"

make_sandbox() {
  SANDBOX="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/sbx.XXXXXX")"
  export HOME="$SANDBOX/home"
  export DOTFILES="$SANDBOX/dotfiles"
  mkdir -p "$HOME" "$DOTFILES/zsh/.config/deep"

  echo "repo-zshrc"     > "$DOTFILES/zsh/.zshrc"
  echo "repo-deepconf"  > "$DOTFILES/zsh/.config/deep/file.conf"

  # kitty fixture — a single config under .config/kitty, mirrors the real module.
  mkdir -p "$DOTFILES/kitty/.config/kitty"
  echo "repo-kittyconf" > "$DOTFILES/kitty/.config/kitty/kitty.conf"

  git -C "$DOTFILES" init -q
  git -C "$DOTFILES" -c user.name=t -c user.email=t@t add -A
  git -C "$DOTFILES" -c user.name=t -c user.email=t@t commit -qm fixture
}

teardown_sandbox() {
  [[ -n "${SANDBOX:-}" && -d "$SANDBOX" ]] && command rm -rf "$SANDBOX"
  return 0
}

# Path of the newest per-run backup dir, or empty if none.
latest_backup_dir() {
  ls -1d "$HOME/.dotfiles-backup"/*/ 2>/dev/null | sort | tail -1
}

# Count of per-run backup dirs.
backup_dir_count() {
  ls -1d "$HOME/.dotfiles-backup"/*/ 2>/dev/null | wc -l
}
