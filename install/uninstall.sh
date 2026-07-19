#!/usr/bin/env bash
# uninstall.sh — wholesale teardown: remove every repo-owned symlink.
#
# Reversibility is the point. This removes ONLY symlinks that resolve into the
# dotfiles repo — real files and foreign symlinks are never disturbed, and (
# unlike `stow -D`) a stray real file never aborts the teardown. It also handles
# stow's folded-directory links (e.g. a whole ~/.config/foo symlinked into the
# repo), removing the link at whatever depth stow placed it.
#
# Pre-install backups under ~/.dotfiles-backup/ are LEFT IN PLACE — teardown is
# safe-by-default, not a second chance to lose data. The newest backup dir is
# printed so you can restore by hand.
#
# Usage:
#   uninstall.sh              # remove all repo-owned links + the dot shim
#   uninstall.sh --dry-run    # show what would be removed, touch nothing

set -euo pipefail

DOTFILES="${DOTFILES:-$(cd "$(dirname "$0")/.." && pwd)}"
DOT_REAL="$(cd "$DOTFILES" && pwd -P)"

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "ERROR: unknown flag: $arg" >&2; exit 2 ;;
  esac
done

# Every module that could have been stowed on a Unix host. A module that was
# never linked (or isn't applicable to this OS) contributes nothing.
MODULES=(zsh git tmux starship nvim kitty)

REMOVED=0
HANDLED=$'\n'   # newline-delimited set of links already handled (dedup dry-run)

# True when $1 is a symlink whose fully-resolved target lives inside the repo.
is_ours_link() {
  [[ -L "$1" ]] || return 1
  local resolved
  resolved="$(readlink -f "$1" 2>/dev/null)" || return 1
  case "$resolved" in "$DOT_REAL"/*) return 0 ;; *) return 1 ;; esac
}

remove_link() { # $1 = absolute path of a repo-owned symlink
  local link="$1"
  case "$HANDLED" in *$'\n'"$link"$'\n'*) return 0 ;; esac
  HANDLED="$HANDLED$link"$'\n'
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  would remove: $link -> $(readlink "$link")"
  else
    rm -f "$link"
    echo "  removed: $link"
    REMOVED=$((REMOVED + 1))
  fi
}

# For one module-relative path, remove the shallowest repo-owned symlink on the
# way down (catches a folded parent dir), else the leaf link itself.
handle_rel() { # $1 = path relative to $HOME
  local cur="$HOME" comp
  local -a comps
  IFS='/' read -ra comps <<< "$1"
  for comp in "${comps[@]}"; do
    cur="$cur/$comp"
    if is_ours_link "$cur"; then
      remove_link "$cur"
      return 0
    fi
  done
}

echo "==> Removing repo-owned symlinks"
for mod in "${MODULES[@]}"; do
  moddir="$DOTFILES/$mod"
  [[ -d "$moddir" ]] || continue
  while IFS= read -r -d '' f; do
    handle_rel "${f#"$moddir"/}"
  done < <(find "$moddir" -type f -print0)
done
[[ $DRY_RUN -eq 0 ]] && echo "    ($REMOVED link(s) removed)"

# The `dot` launcher shim bootstrap drops in ~/.local/bin. Remove it only if it
# is a symlink pointing back into THIS repo — never a real file someone placed.
DOT_SHIM="$HOME/.local/bin/dot"
if [[ -L "$DOT_SHIM" ]]; then
  target="$(readlink "$DOT_SHIM")"
  case "$target" in
    "$DOTFILES"/*|"$DOT_REAL"/*)
      if [[ $DRY_RUN -eq 1 ]]; then
        echo "==> would remove dot shim: $DOT_SHIM -> $target"
      else
        rm -f "$DOT_SHIM"
        echo "==> removed dot shim: $DOT_SHIM"
      fi
      ;;
  esac
fi

# Point the user at their backups; never auto-restore (which run? which file?).
latest="$(ls -1d "$HOME/.dotfiles-backup"/*/ 2>/dev/null | sort | tail -1 || true)"
if [[ -n "$latest" ]]; then
  echo ""
  echo "==> Your pre-install backups are preserved. Newest:"
  echo "    $latest"
  echo "    Restore a file with: mv \"${latest}<relative-path>\" \"\$HOME/<relative-path>\""
fi

echo ""
if [[ $DRY_RUN -eq 1 ]]; then
  echo "==> Dry run complete — nothing was removed."
else
  echo "==> Uninstall complete. Open a new shell to drop the old environment."
fi
