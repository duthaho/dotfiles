#!/usr/bin/env bash
# stow-modules.sh — stows a list of modules. Defaults to v1 Unix set.
# Usage:
#   stow-modules.sh                    # stow default set
#   stow-modules.sh --dry-run          # show what would happen
#   stow-modules.sh --non-interactive  # resolve conflicts by auto-backup
#   stow-modules.sh zsh git nvim       # stow only these
#   stow-modules.sh --remove zsh       # un-stow these
#
# Conflict flow — when a real file (or a symlink stow doesn't own) sits where
# a link must go:
#   interactive:      per conflict, prompt [s]kip / [b]ackup / [A]ll
#   non-interactive:  auto-backup every conflict (also when stdin is not a TTY)
# Backups are moved to $HOME/.dotfiles-backup/<YYYYMMDD-HHMMSS>/<relative-path>.
# The directory is created only if a backup actually happens, and is unique
# per run. Repo content is never modified by stowing.

set -euo pipefail

DOTFILES="${DOTFILES:-$(cd "$(dirname "$0")/.." && pwd)}"
DEFAULT_MODULES=(zsh git tmux starship)

DRY_RUN=""
REMOVE=""
NON_INTERACTIVE=0
MODULES=()

for arg in "$@"; do
  case "$arg" in
    --dry-run)         DRY_RUN="-n" ;;
    --remove)          REMOVE="-D" ;;
    --non-interactive) NON_INTERACTIVE=1 ;;
    *)                 MODULES+=("$arg") ;;
  esac
done

# No TTY on stdin (CI, piped) → nobody can answer a prompt.
# STOW_MODULES_FORCE_INTERACTIVE=1 lets tests drive the prompt via a pipe.
if [[ "${STOW_MODULES_FORCE_INTERACTIVE:-0}" != "1" ]] && ! [ -t 0 ]; then
  NON_INTERACTIVE=1
fi

if [[ ${#MODULES[@]} -eq 0 ]]; then
  MODULES=("${DEFAULT_MODULES[@]}")
fi

BACKUP_ROOT="$HOME/.dotfiles-backup"
BACKUP_DIR=""   # created lazily on first backup
BACKUP_ALL=0    # set when the user answers [A]ll

# Unique per-run backup dir; -2, -3… suffix if two runs share a timestamp.
ensure_backup_dir() {
  [[ -n "$BACKUP_DIR" ]] && return 0
  local base
  base="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
  BACKUP_DIR="$base"
  local n=2
  while [[ -e "$BACKUP_DIR" ]]; do
    BACKUP_DIR="$base-$n"
    n=$((n + 1))
  done
  mkdir -p "$BACKUP_DIR"
}

backup_one() { # $1 = path relative to $HOME
  local rel="$1"
  ensure_backup_dir
  mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
  mv "$HOME/$rel" "$BACKUP_DIR/$rel"
  echo "    backed up: ~/$rel -> $BACKUP_DIR/$rel"
}

# Build a stow --ignore arg that matches exactly ONE package-relative path.
# The regex is anchored ^…$ against the FULL relative path. A leading (^|/)
# alternative must NOT be used: the "/foo$" branch also matches the basename
# of any same-named file deeper in the tree (e.g. skipping ".zshrc" would then
# silently drop "subdir/.zshrc" too). Anchoring at ^ keeps it path-specific.
ignore_arg() { # $1 = path relative to the module root
  local esc
  esc="$(printf '%s' "$1" | sed 's/[][\.^$*+?(){}|\\]/\\&/g')"
  printf -- '--ignore=^%s$' "$esc"
}

# Print the relative paths stow reports as conflicts for a module.
# Known forms (stow 2.3.1):
#   * existing target is neither a link nor a directory: <rel>   (real file)
#   * existing target is not owned by stow: <rel>                (foreign link)
# Unknown conflict forms are NOT swallowed — stow itself aborts loudly on
# them in the final invocation below.
detect_conflicts() { # $1 = module
  # stow exits 1 when conflicts exist; with pipefail that would sink the
  # whole pipeline, so neutralize stow's status — sed's is what matters.
  { stow -n -t "$HOME" "$1" 2>&1 || true; } | sed -n \
    -e 's/^  \* existing target is neither a link nor a directory: //p' \
    -e 's/^  \* existing target is not owned by stow: //p'
}

prompt_action() { # $1 = rel; echoes s|b|A
  local rel="$1" ans
  while true; do
    read -r -p "    conflict: ~/$rel exists. [s]kip / [b]ackup then link / [A] backup all: " ans || { echo "s"; return; }
    case "$ans" in
      s|S) echo "s"; return ;;
      b|B) echo "b"; return ;;
      A)   echo "A"; return ;;
      *)   echo "    please answer s, b, or A" >&2 ;;
    esac
  done
}

process_module() { # $1 = module (stow direction only, never --remove)
  local mod="$1"
  local ignores=()
  local rel action conflicts

  conflicts="$(detect_conflicts "$mod")"
  if [[ -n "$conflicts" ]]; then
    # Loop over FD 3, NOT stdin — stdin must stay free for prompt answers.
    while IFS= read -r rel <&3; do
      [[ -z "$rel" ]] && continue

      if [[ -n "$DRY_RUN" ]]; then
        if [[ $NON_INTERACTIVE -eq 1 || $BACKUP_ALL -eq 1 ]]; then
          echo "    conflict: ~/$rel — would back up to $BACKUP_ROOT/<run>/ and link"
        else
          echo "    conflict: ~/$rel — would prompt [s]kip / [b]ackup / [A]ll"
        fi
        # Ignore it so the simulation below still shows the rest of the plan.
        ignores+=("$(ignore_arg "$rel")")
        continue
      fi

      if [[ $NON_INTERACTIVE -eq 1 || $BACKUP_ALL -eq 1 ]]; then
        action="b"
      else
        action="$(prompt_action "$rel")"
      fi

      case "$action" in
        s)
          echo "    skipped: ~/$rel (kept existing file)"
          ignores+=("$(ignore_arg "$rel")")
          ;;
        A)
          BACKUP_ALL=1
          backup_one "$rel"
          ;;
        b)
          backup_one "$rel"
          ;;
      esac
    done 3<<< "$conflicts"
  fi

  # ${arr[@]+...} keeps empty-array expansion safe on bash 3.2 (macOS).
  stow $DRY_RUN -t "$HOME" ${ignores[@]+"${ignores[@]}"} "$mod"
}

cd "$DOTFILES"

for mod in "${MODULES[@]}"; do
  if [[ ! -d "$mod" ]]; then
    echo "WARN: module '$mod' not found in $DOTFILES, skipping" >&2
    continue
  fi
  echo "==> stow ${REMOVE:-$DRY_RUN} $mod"
  if [[ -n "$REMOVE" ]]; then
    stow $DRY_RUN -t "$HOME" -D "$mod"
  else
    process_module "$mod"
  fi
done
