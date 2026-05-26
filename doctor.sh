#!/usr/bin/env bash
# no -e: keep checking after a failure.
set -uo pipefail

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

check_bin_info() {
  if command -v "$1" >/dev/null 2>&1; then
    ok "$1 on PATH ($(command -v "$1"))"
  else
    info "$1 not installed (optional)"
  fi
}

check_symlink() {
  local link="$1" expected_prefix="$2"
  if [[ -L "$link" ]]; then
    # readlink (no flag) returns the raw target (often relative on stow links).
    # readlink -f resolves through the chain to an absolute path — that's what
    # we compare against $expected_prefix. Display the raw target since it's
    # more readable.
    local raw_target abs_target
    raw_target=$(readlink "$link")
    abs_target=$(readlink -f "$link" 2>/dev/null || echo "$raw_target")
    if [[ "$abs_target" == "$expected_prefix"* ]]; then
      ok "$link → $raw_target"
    else
      fail "$link → $raw_target resolves to $abs_target (expected under $expected_prefix)"
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
elif [[ -n "${CI:-}" ]]; then
  # --non-interactive skips chsh; CI doesn't need a login shell change.
  info "\$SHELL is $SHELL (chsh skipped in CI / non-interactive mode)"
else
  fail "\$SHELL is $SHELL (expected zsh; run 'chsh -s \$(command -v zsh)')"
fi

echo ""
echo "== Identity =="
if [[ -f "$HOME/.gitconfig.local" ]]; then
  ok "~/.gitconfig.local exists"
  # Read via --file: CI sets GIT_CONFIG_GLOBAL to a temp file, breaking the
  # ~/.gitconfig [include] chain. Sidecar is the contract per README.
  name=$(git config --file "$HOME/.gitconfig.local" --get user.name 2>/dev/null || true)
  email=$(git config --file "$HOME/.gitconfig.local" --get user.email 2>/dev/null || true)
  if [[ -n "$name" && -n "$email" ]]; then
    ok "git identity resolves: $name <$email>"
  else
    fail "git config user.name/user.email do not resolve in ~/.gitconfig.local"
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
echo "== CLI cluster (optional) =="
check_bin_info zoxide
check_bin_info atuin
check_bin_info bat
check_bin_info fd
check_bin_info delta
check_bin_info dot

echo ""
echo "== Optional =="
if command -v nvim >/dev/null 2>&1; then
  ok "nvim installed"
  # init.lua may be a direct symlink, OR reachable via a parent-dir symlink
  # (stow chooses one based on whether ~/.config/nvim already existed).
  # readlink -f handles both cases by resolving the full chain.
  init_resolved=$(readlink -f "$HOME/.config/nvim/init.lua" 2>/dev/null || true)
  if [[ "$init_resolved" == "$DOTFILES"* ]]; then
    ok "nvim config symlinked → $init_resolved"
  else
    info "nvim installed but config not stowed (run: install/stow-modules.sh nvim)"
  fi
else
  info "nvim not installed (opt-in)"
fi

echo ""
echo "== OS defaults =="
if [[ "$(uname -s)" == "Darwin" ]]; then
  match=0; total=3
  [[ "$(defaults read NSGlobalDomain KeyRepeat 2>/dev/null)" == "2" ]] && match=$((match+1))
  [[ "$(defaults read NSGlobalDomain AppleShowAllExtensions 2>/dev/null)" == "1" ]] && match=$((match+1))
  [[ "$(defaults read com.apple.dock autohide 2>/dev/null)" == "1" ]] && match=$((match+1))
  if [[ $match -eq $total ]]; then
    ok "OS defaults applied ($match/$total spot-checks match)"
  elif [[ $match -eq 0 ]]; then
    info "OS defaults not applied (run: ./bootstrap.sh --apply-defaults)"
  else
    info "OS defaults partial ($match/$total spot-checks match)"
  fi
else
  info "OS defaults: macOS only; current OS is $(uname -s)"
fi

echo ""
echo "== Summary =="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"

[[ $FAIL -eq 0 ]]
