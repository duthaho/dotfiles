#!/usr/bin/env bash
# stow-modules.sh — stows a list of modules. Defaults to v1 Unix set.
# Usage:
#   stow-modules.sh                 # stow default set
#   stow-modules.sh --dry-run       # show what would happen
#   stow-modules.sh zsh git nvim    # stow only these
#   stow-modules.sh --remove zsh    # un-stow these

set -euo pipefail

DOTFILES="${DOTFILES:-$(cd "$(dirname "$0")/.." && pwd)}"
DEFAULT_MODULES=(zsh git tmux starship)

DRY_RUN=""
REMOVE=""
MODULES=()

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN="-n" ;;
    --remove)  REMOVE="-D" ;;
    *)         MODULES+=("$arg") ;;
  esac
done

if [[ ${#MODULES[@]} -eq 0 ]]; then
  MODULES=("${DEFAULT_MODULES[@]}")
fi

cd "$DOTFILES"

for mod in "${MODULES[@]}"; do
  if [[ ! -d "$mod" ]]; then
    echo "WARN: module '$mod' not found in $DOTFILES, skipping" >&2
    continue
  fi
  echo "==> stow ${REMOVE:-$DRY_RUN} $mod"
  # --adopt only on first-time stow, never with --remove
  if [[ -n "$REMOVE" ]]; then
    stow $DRY_RUN -t "$HOME" -D "$mod"
  else
    stow $DRY_RUN --adopt -t "$HOME" "$mod"
  fi
done

# If any module was adopted, the repo's tracked files may now differ.
# Print a hint so the user knows to check `git status`.
if [[ -z "$DRY_RUN" && -z "$REMOVE" ]]; then
  if ! git -C "$DOTFILES" diff --quiet 2>/dev/null; then
    echo ""
    echo "==> NOTE: stow --adopt moved existing dotfiles into the repo."
    echo "    Review with: git -C $DOTFILES diff"
  fi
fi
