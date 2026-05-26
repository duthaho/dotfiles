#!/usr/bin/env bash
set -euo pipefail

DOTFILES="${DOTFILES:-$(cd "$(dirname "$0")/.." && pwd)}"
BREWFILE="$DOTFILES/install/packages/Brewfile"

if ! command -v brew >/dev/null 2>&1; then
  echo "==> Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [[ ! -f "$BREWFILE" ]]; then
  echo "ERROR: Brewfile not found at $BREWFILE" >&2
  exit 1
fi

echo "==> Installing toolchain via brew bundle --file=$BREWFILE"
brew bundle --file="$BREWFILE"
