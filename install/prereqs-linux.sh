#!/usr/bin/env bash
# prereqs-linux.sh — installs the v1 toolchain via apt (Debian/Ubuntu)
# or dnf (Fedora). Safe to re-run.

set -euo pipefail

if command -v apt-get >/dev/null 2>&1; then
  echo "==> Installing toolchain via apt"
  sudo apt-get update -y
  sudo apt-get install -y \
    stow zsh tmux git curl fzf ripgrep
  # Starship installs separately on Debian-based systems
  if ! command -v starship >/dev/null 2>&1; then
    echo "==> Installing Starship"
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
  fi
  # eza isn't in older apt repos
  if ! command -v eza >/dev/null 2>&1; then
    echo "==> NOTE: eza unavailable via apt on this distro; falling back to 'exa' if present"
    sudo apt-get install -y exa 2>/dev/null || true
  fi
elif command -v dnf >/dev/null 2>&1; then
  echo "==> Installing toolchain via dnf"
  sudo dnf install -y \
    stow zsh tmux git curl fzf ripgrep starship eza
else
  echo "ERROR: no supported package manager found (need apt-get or dnf)" >&2
  exit 1
fi
