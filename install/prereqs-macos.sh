#!/usr/bin/env bash
# prereqs-macos.sh — installs the v1 toolchain via Homebrew.
# Safe to re-run; brew install no-ops on installed packages.

set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "==> Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

PACKAGES=(
  stow
  zsh
  tmux
  starship
  git
  curl
  fzf
  ripgrep
  eza
  lazygit
)

echo "==> Installing toolchain via brew"
brew install "${PACKAGES[@]}"
