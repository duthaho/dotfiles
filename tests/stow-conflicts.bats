#!/usr/bin/env bats
# Tests for install/stow-modules.sh conflict flow.

load helpers/setup

setup()    { make_sandbox; }
teardown() { teardown_sandbox; }

@test "sanity: clean home stows fixture module without conflicts" {
  run "$SUT" zsh
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.zshrc")" != "" ]
  [ "$(cat "$HOME/.zshrc")" = "repo-zshrc" ]
}

# --- non-interactive conflict flow (spec criteria 1–3) ---

@test "non-interactive: conflicting real file is backed up, then linked" {
  echo "home-zshrc" > "$HOME/.zshrc"

  run "$SUT" --non-interactive zsh
  [ "$status" -eq 0 ]

  # target is now a symlink into the repo, resolving to repo content
  [ -L "$HOME/.zshrc" ]
  [ "$(cat "$HOME/.zshrc")" = "repo-zshrc" ]

  # original content preserved under ~/.dotfiles-backup/<ts>/.zshrc
  local bdir; bdir="$(latest_backup_dir)"
  [ -n "$bdir" ]
  [ "$(cat "$bdir/.zshrc")" = "home-zshrc" ]

  # backup path was printed
  [[ "$output" == *".dotfiles-backup"* ]]
}

@test "non-interactive: nested conflict preserves relative path in backup" {
  mkdir -p "$HOME/.config/deep"
  echo "home-deepconf" > "$HOME/.config/deep/file.conf"

  run "$SUT" --non-interactive zsh
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.config/deep/file.conf")" = "repo-deepconf" ]

  local bdir; bdir="$(latest_backup_dir)"
  [ "$(cat "$bdir/.config/deep/file.conf")" = "home-deepconf" ]
}

@test "adopt is gone: repo tracked content never changes on conflict" {
  echo "home-zshrc" > "$HOME/.zshrc"

  run "$SUT" --non-interactive zsh
  [ "$status" -eq 0 ]
  run git -C "$DOTFILES" status --porcelain
  [ "$output" = "" ]
  [ "$(cat "$DOTFILES/zsh/.zshrc")" = "repo-zshrc" ]
}

@test "non-interactive: no conflicts means no backup dir is created" {
  run "$SUT" --non-interactive zsh
  [ "$status" -eq 0 ]
  [ ! -d "$HOME/.dotfiles-backup" ]
}

# --- interactive prompt flow (spec criterion 1) ---
# STOW_MODULES_FORCE_INTERACTIVE=1 keeps prompts alive with piped stdin.

run_interactive() { # $1 = piped answers, rest = script args
  local answers="$1"; shift
  run bash -c "printf '%b' '$answers' | STOW_MODULES_FORCE_INTERACTIVE=1 '$SUT' \"\$@\"" _ "$@"
}

@test "interactive skip: file kept, rest of module still linked" {
  echo "home-zshrc" > "$HOME/.zshrc"

  run_interactive 's\n' zsh
  [ "$status" -eq 0 ]

  # skipped file untouched, not a symlink, no backup made
  [ ! -L "$HOME/.zshrc" ]
  [ "$(cat "$HOME/.zshrc")" = "home-zshrc" ]
  [ ! -d "$HOME/.dotfiles-backup" ]

  # the module's other file still linked
  [ "$(cat "$HOME/.config/deep/file.conf")" = "repo-deepconf" ]
  [[ "$output" == *"skipped: ~/.zshrc"* ]]
}

@test "skip does not drop a same-basename file elsewhere in the module" {
  # Regression: the skip --ignore regex must be anchored to the full relative
  # path, not (^|/)basename$ — otherwise skipping ~/.zshrc silently ignores
  # a deeper file that happens to share the basename.
  mkdir -p "$DOTFILES/zsh/nested"
  echo "repo-nested-zshrc" > "$DOTFILES/zsh/nested/.zshrc"
  # pre-create nested/ in $HOME so stow can't fold the whole subtree into one link
  mkdir -p "$HOME/nested"
  echo "home-zshrc" > "$HOME/.zshrc"

  run_interactive 's\n' zsh
  [ "$status" -eq 0 ]

  # top-level skipped and kept
  [ ! -L "$HOME/.zshrc" ]
  [ "$(cat "$HOME/.zshrc")" = "home-zshrc" ]
  # the same-basename sibling MUST still be linked
  [ -L "$HOME/nested/.zshrc" ]
  [ "$(cat "$HOME/nested/.zshrc")" = "repo-nested-zshrc" ]
}

@test "interactive backup: file backed up then linked" {
  echo "home-zshrc" > "$HOME/.zshrc"

  run_interactive 'b\n' zsh
  [ "$status" -eq 0 ]
  [ -L "$HOME/.zshrc" ]
  [ "$(cat "$(latest_backup_dir)/.zshrc")" = "home-zshrc" ]
}

@test "interactive backup-all: A answers once, applies to all remaining conflicts" {
  echo "home-zshrc" > "$HOME/.zshrc"
  mkdir -p "$HOME/.config/deep"
  echo "home-deepconf" > "$HOME/.config/deep/file.conf"

  # single 'A' — second conflict must NOT prompt again
  run_interactive 'A\n' zsh
  [ "$status" -eq 0 ]
  local bdir; bdir="$(latest_backup_dir)"
  [ "$(cat "$bdir/.zshrc")" = "home-zshrc" ]
  [ "$(cat "$bdir/.config/deep/file.conf")" = "home-deepconf" ]
  [ -L "$HOME/.zshrc" ]
  [ "$(cat "$HOME/.config/deep/file.conf")" = "repo-deepconf" ]
}

@test "interactive invalid answer reprompts, then honors valid one" {
  echo "home-zshrc" > "$HOME/.zshrc"

  run_interactive 'x\nb\n' zsh
  [ "$status" -eq 0 ]
  [ -L "$HOME/.zshrc" ]
  [ "$(cat "$(latest_backup_dir)/.zshrc")" = "home-zshrc" ]
}

# --- --dry-run preview (spec criterion 4) ---

@test "dry-run with conflicts: prints planned action, touches nothing" {
  echo "home-zshrc" > "$HOME/.zshrc"

  run "$SUT" --dry-run zsh
  [ "$status" -eq 0 ]
  [[ "$output" == *"conflict: ~/.zshrc"* ]]
  [[ "$output" == *"would back up"* ]]

  # nothing changed: no backup dir, file intact, nothing linked
  [ ! -d "$HOME/.dotfiles-backup" ]
  [ ! -L "$HOME/.zshrc" ]
  [ "$(cat "$HOME/.zshrc")" = "home-zshrc" ]
  [ ! -e "$HOME/.config/deep/file.conf" ]
}

@test "dry-run interactive mode says it would prompt" {
  echo "home-zshrc" > "$HOME/.zshrc"

  run bash -c "STOW_MODULES_FORCE_INTERACTIVE=1 '$SUT' --dry-run zsh < /dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"would prompt"* ]]
  [ ! -d "$HOME/.dotfiles-backup" ]
}

# --- unique backup dirs (spec criterion 6) ---

@test "two conflicting runs produce two distinct backup dirs" {
  echo "one" > "$HOME/.zshrc"
  run "$SUT" --non-interactive zsh
  [ "$status" -eq 0 ]

  # recreate the conflict immediately (same wall-clock second is likely)
  command rm "$HOME/.zshrc"
  echo "two" > "$HOME/.zshrc"
  run "$SUT" --non-interactive zsh
  [ "$status" -eq 0 ]

  [ "$(backup_dir_count)" -eq 2 ]
  # both contents survived, in different dirs
  run bash -c "cat \"\$HOME\"/.dotfiles-backup/*/.zshrc | sort"
  [ "${lines[0]}" = "one" ]
  [ "${lines[1]}" = "two" ]
}

@test "stdin not a TTY implies non-interactive auto-backup" {
  echo "home-zshrc" > "$HOME/.zshrc"

  # bats runs without a TTY on stdin already; call WITHOUT the flag
  run "$SUT" zsh
  [ "$status" -eq 0 ]
  [ -L "$HOME/.zshrc" ]
  local bdir; bdir="$(latest_backup_dir)"
  [ "$(cat "$bdir/.zshrc")" = "home-zshrc" ]
}
