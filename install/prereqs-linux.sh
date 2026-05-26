#!/usr/bin/env bash
set -euo pipefail

DOTFILES="${DOTFILES:-$(cd "$(dirname "$0")/.." && pwd)}"

manifest_packages() {
  grep -vE '^\s*(#|$)' "$1"
}

if command -v apt-get >/dev/null 2>&1; then
  echo "==> Installing toolchain via apt"
  sudo apt-get update -y
  manifest_packages "$DOTFILES/install/packages/apt-packages.txt" \
    | xargs -r sudo apt-get install -y

  # Not in apt on Debian-based systems.
  if ! command -v starship >/dev/null 2>&1; then
    echo "==> Installing Starship to ~/.local/bin"
    mkdir -p "$HOME/.local/bin"
    curl -sS https://starship.rs/install.sh \
      | sh -s -- --yes --bin-dir "$HOME/.local/bin"
  fi

  # Not in apt < Ubuntu 24.04; fall back to exa.
  if ! command -v eza >/dev/null 2>&1; then
    if ! sudo apt-get install -y eza 2>/dev/null; then
      echo "==> NOTE: eza unavailable via apt on this distro; trying exa"
      sudo apt-get install -y exa 2>/dev/null || true
    fi
  fi

  # Older Ubuntu/Debian need GitHub's official apt repo.
  if ! command -v gh >/dev/null 2>&1; then
    if ! sudo apt-get install -y gh 2>/dev/null; then
      echo "==> apt 'gh' unavailable; installing from official GitHub apt repo"
      sudo install -dm 755 /etc/apt/keyrings
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
      sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      sudo apt-get update -y
      sudo apt-get install -y gh
    fi
  fi

  # Not in apt < Ubuntu 24.04; fall back to curl installer.
  if ! command -v atuin >/dev/null 2>&1; then
    if ! sudo apt-get install -y atuin 2>/dev/null; then
      echo "==> apt 'atuin' unavailable; installing via official curl installer"
      curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
    fi
  fi

  # Debian ships `bat` as `batcat`; shim for cross-distro consistency.
  if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    echo "==> Symlinked $(command -v batcat) → ~/.local/bin/bat"
  fi

  # Debian ships `fd` as `fdfind`; same shim pattern.
  if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    echo "==> Symlinked $(command -v fdfind) → ~/.local/bin/fd"
  fi

  # Not in apt < Ubuntu 22.04; fall back to GitHub release tarball.
  if ! command -v delta >/dev/null 2>&1; then
    if ! sudo apt-get install -y git-delta 2>/dev/null; then
      echo "==> apt 'git-delta' unavailable; installing from GitHub release"
      DELTA_VERSION="0.18.2"
      case "$(uname -m)" in
        x86_64|amd64)  DELTA_ARCH="x86_64-unknown-linux-gnu" ;;
        aarch64|arm64) DELTA_ARCH="aarch64-unknown-linux-gnu" ;;
        *) echo "ERROR: unsupported CPU $(uname -m) for delta" >&2; exit 1 ;;
      esac
      DELTA_TARBALL="delta-${DELTA_VERSION}-${DELTA_ARCH}.tar.gz"
      mkdir -p "$HOME/.local/bin"
      curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/${DELTA_TARBALL}" \
        | tar -xz -C /tmp
      install -m 755 "/tmp/delta-${DELTA_VERSION}-${DELTA_ARCH}/delta" "$HOME/.local/bin/delta"
      rm -rf "/tmp/delta-${DELTA_VERSION}-${DELTA_ARCH}"
    fi
  fi
elif command -v dnf >/dev/null 2>&1; then
  echo "==> Installing toolchain via dnf"
  manifest_packages "$DOTFILES/install/packages/dnf-packages.txt" \
    | xargs -r sudo dnf install -y
else
  echo "ERROR: no supported package manager found (need apt-get or dnf)" >&2
  exit 1
fi
