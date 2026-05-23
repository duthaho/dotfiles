#!/usr/bin/env bash
# doctor.sh — post-install verification. Prints a checklist with
# pass/fail/info rows. Exits 0 if all required rows pass.

set -uo pipefail   # no -e: we want to keep checking even after a failure

DOTFILES="${DOTFILES:-$(cd "$(dirname "$0")" && pwd)}"
PASS=0
FAIL=0

ok()   { printf "  \033[32m✓\033[0m %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  \033[31m✗\033[0m %s\n" "$1"; FAIL=$((FAIL+1)); }
info() { printf "  \033[33m·\033[0m %s\n" "$1"; }

check_bin() {
  if command -v "$1" >/dev/null 2>&1; then
    ok "$1 on PATH ($(command -v "$1"))"
  else
    fail "$1 NOT on PATH"
  fi
}

check_symlink() {
  local link="$1" expected_prefix="$2"
  if [[ -L "$link" ]]; then
    local target; target=$(readlink "$link")
    if [[ "$target" == *"$expected_prefix"* ]]; then
      ok "$link → $target"
    else
      fail "$link is a symlink but points to $target (expected something under $expected_prefix)"
    fi
  elif [[ -e "$link" ]]; then
    fail "$link exists but is not a symlink"
  else
    fail "$link does not exist"
  fi
}

echo "== Required binaries =="
check_bin stow
check_bin zsh
check_bin git
check_bin tmux
check_bin starship

echo ""
echo "== Default shell =="
if [[ "$SHELL" == *zsh ]]; then
  ok "\$SHELL is zsh ($SHELL)"
else
  fail "\$SHELL is $SHELL (expected zsh; run 'chsh -s \$(command -v zsh)')"
fi

echo ""
echo "== Identity =="
if [[ -f "$HOME/.gitconfig.local" ]]; then
  ok "~/.gitconfig.local exists"
  name=$(git config --get user.name 2>/dev/null || true)
  email=$(git config --get user.email 2>/dev/null || true)
  if [[ -n "$name" && -n "$email" ]]; then
    ok "git identity resolves: $name <$email>"
  else
    fail "git config user.name/user.email do not resolve"
  fi
else
  fail "~/.gitconfig.local missing — run install/seed-identity.sh"
fi

echo ""
echo "== Symlinks =="
check_symlink "$HOME/.zshrc"                "$DOTFILES"
check_symlink "$HOME/.zshenv"               "$DOTFILES"
check_symlink "$HOME/.gitconfig"            "$DOTFILES"
check_symlink "$HOME/.gitignore_global"     "$DOTFILES"
check_symlink "$HOME/.tmux.conf"            "$DOTFILES"
check_symlink "$HOME/.config/starship.toml" "$DOTFILES"

echo ""
echo "== Optional =="
if command -v nvim >/dev/null 2>&1; then
  ok "nvim installed"
  if [[ -L "$HOME/.config/nvim/init.lua" ]]; then
    ok "nvim config symlinked"
  else
    info "nvim installed but config not stowed (run: install/stow-modules.sh nvim)"
  fi
else
  info "nvim not installed (opt-in)"
fi

echo ""
echo "== Summary =="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"

[[ $FAIL -eq 0 ]]
