#!/usr/bin/env bash
# bootstrap.sh — entry point for macOS / Linux / WSL.
# Five steps: detect → prereqs → identity → stow → optional nvim + chsh.

set -euo pipefail

DOTFILES="${DOTFILES:-$(cd "$(dirname "$0")" && pwd)}"
export DOTFILES

DRY_RUN=""
INSTALL_NVIM="${INSTALL_NVIM:-}"

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN="--dry-run" ;;
    --with-nvim) INSTALL_NVIM=1 ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--dry-run] [--with-nvim]

  --dry-run     Print actions without performing them
  --with-nvim   Skip the prompt; install Neovim module

Environment:
  DOTFILES      Path to repo (defaults to dirname of this script)
  INSTALL_NVIM  Set to 1 to skip the nvim prompt
EOF
      exit 0
      ;;
    *)
      echo "ERROR: unknown flag: $arg" >&2
      exit 2
      ;;
  esac
done

# 0. Ensure helper scripts are executable. The +x bit doesn't always survive
# transfers from Windows filesystems (git on Windows, scp/rsync, zip archives).
chmod +x "$DOTFILES/doctor.sh" "$DOTFILES/install/"*.sh 2>/dev/null || true

# 1. Detect OS
OS=$("$DOTFILES/install/detect-os.sh")
echo "==> Detected: $OS"

if [[ -n "$DRY_RUN" ]]; then
  echo "==> DRY RUN — no changes will be made"
fi

# 2. Prereqs
case "$OS" in
  macos)
    [[ -z "$DRY_RUN" ]] && "$DOTFILES/install/prereqs-macos.sh"
    ;;
  linux|wsl)
    [[ -z "$DRY_RUN" ]] && "$DOTFILES/install/prereqs-linux.sh"
    ;;
esac

# 3. Identity
[[ -z "$DRY_RUN" ]] && "$DOTFILES/install/seed-identity.sh"

# 4. Stow default modules
"$DOTFILES/install/stow-modules.sh" $DRY_RUN

# 5. Optional: Oh My Zsh + plugins (separately from package manager)
if [[ -z "$DRY_RUN" && ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "==> Installing Oh My Zsh"
  RUNZSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  # Install the two plugins we use
  ZSH_PLUGINS="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
  if [[ ! -d "$ZSH_PLUGINS/zsh-autosuggestions" ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
      "$ZSH_PLUGINS/zsh-autosuggestions"
  fi
  if [[ ! -d "$ZSH_PLUGINS/zsh-syntax-highlighting" ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
      "$ZSH_PLUGINS/zsh-syntax-highlighting"
  fi
fi

# 6. Optional: nvim module
if [[ -z "$DRY_RUN" ]]; then
  if [[ "$INSTALL_NVIM" == "1" ]] || \
     "$DOTFILES/install/prompt-yn.sh" "Install Neovim config?"; then
    echo "==> Installing Neovim and its prereqs"
    case "$OS" in
      macos)       brew install neovim ripgrep fd ;;
      linux|wsl)
        # Install search deps via system package manager (apt's versions are fine).
        if command -v apt-get >/dev/null 2>&1; then
          sudo apt-get install -y ripgrep fd-find
        elif command -v dnf >/dev/null 2>&1; then
          sudo dnf install -y ripgrep fd-find
        fi
        # Install nvim from the official prebuilt tarball. Ubuntu/Debian apt
        # ships 0.9.x, which nvim-lspconfig has deprecated (needs 0.11+).
        NVIM_PREFIX="$HOME/.local/share/nvim-stable"
        if [[ ! -x "$NVIM_PREFIX/bin/nvim" ]]; then
          echo "==> Installing Neovim stable from official tarball"
          mkdir -p "$NVIM_PREFIX" "$HOME/.local/bin"
          curl -fsSL https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.tar.gz \
            | tar -xz -C "$NVIM_PREFIX" --strip-components=1
          ln -sf "$NVIM_PREFIX/bin/nvim" "$HOME/.local/bin/nvim"
        fi
        ;;
    esac
    "$DOTFILES/install/stow-modules.sh" nvim
  fi
fi

# 7. Switch default shell to zsh (only if not already)
if [[ -z "$DRY_RUN" && "$SHELL" != *zsh ]]; then
  ZSH_PATH="$(command -v zsh)"
  if [[ -n "$ZSH_PATH" ]]; then
    echo "==> Setting default shell to $ZSH_PATH"
    # Try sudo first (handles VPS / cloud users who have no Unix password but
    # have sudo). Fall back to plain chsh (handles macOS / local users where
    # PAM will accept their password). 'sudo -n' = non-interactive: skips the
    # sudo branch silently if it would prompt for a password.
    if sudo -n chsh -s "$ZSH_PATH" "$USER" 2>/dev/null; then
      :
    elif chsh -s "$ZSH_PATH"; then
      :
    else
      echo "WARN: chsh failed; change shell manually:"
      echo "      sudo chsh -s $ZSH_PATH $USER"
    fi
  fi
fi

echo ""
echo "==> Bootstrap complete. Open a new terminal."
echo "==> Verify with: $DOTFILES/doctor.sh"

# Nudge user to authenticate with GitHub if gh is installed but not signed in.
if [[ -z "$DRY_RUN" ]] && command -v gh >/dev/null 2>&1; then
  if ! gh auth status >/dev/null 2>&1; then
    echo "==> Next: run 'gh auth login' to set up GitHub SSH + credential helper"
  fi
fi
