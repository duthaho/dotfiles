#!/usr/bin/env bash
# fonts.sh — install JetBrainsMono Nerd Font on macOS / Linux.
#
# This repo's standard font (Windows installs it via prereqs-windows.ps1).
# Everything here is BEST-EFFORT: a package/download hiccup prints a warning
# and returns 0 so it never aborts bootstrap. Idempotent: skips if already
# installed.
#
# Usage:  install/fonts.sh <macos|linux>
#   (also sourceable: `source fonts.sh` then `install_jetbrains_nerd_font <os>`)

set -euo pipefail

NERD_FONTS_VERSION="v3.4.0"
FONT_ASSET="JetBrainsMono.tar.xz"

_font_already_present() {
  command -v fc-list >/dev/null 2>&1 && fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"
}

install_jetbrains_nerd_font() { # $1 = macos|linux
  local os="$1"

  case "$os" in
    macos)
      if command -v brew >/dev/null 2>&1; then
        echo "==> Installing JetBrainsMono Nerd Font (brew cask)"
        brew install --cask font-jetbrains-mono-nerd-font \
          || echo "WARN: font cask install failed; install it manually" >&2
      else
        echo "WARN: brew not found; skipping Nerd Font install" >&2
      fi
      ;;
    linux)
      if _font_already_present; then
        echo "==> JetBrainsMono Nerd Font already installed"
        return 0
      fi
      echo "==> Installing JetBrainsMono Nerd Font ($NERD_FONTS_VERSION) to ~/.local/share/fonts"
      local dest="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
      local url="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/${FONT_ASSET}"
      local tmp
      tmp="$(mktemp -d)"
      if curl -fsSL "$url" | tar -xJ -C "$tmp" 2>/dev/null; then
        mkdir -p "$dest"
        find "$tmp" -name '*.ttf' -exec cp {} "$dest/" \;
        command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$dest" >/dev/null 2>&1 || true
        echo "==> Installed Nerd Font TTFs to $dest"
      else
        echo "WARN: Nerd Font download/extract failed ($url); install it manually" >&2
      fi
      command rm -rf "$tmp"
      ;;
    *)
      echo "WARN: fonts.sh: unknown OS '$os', skipping" >&2
      ;;
  esac
  return 0
}

# Run directly (not when sourced).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  install_jetbrains_nerd_font "${1:-}"
fi
