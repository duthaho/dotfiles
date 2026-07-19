#!/usr/bin/env bash
# plan.sh — read-only drift report: how does this machine diverge from repo
# intent? One always-available, whole-machine view answering "if I ran bootstrap
# now, what would change?" — without changing anything.
#
# Sections: symlinks (would stow link/back up?), packages (would the manifest
# install anything?), OS defaults (macOS spot-checks; opt-in, never counted as
# drift). Touches nothing.
#
# Exit: 0 = machine matches repo intent; 2 = drift (bootstrap/stow would change
# something); 1 = usage error.

set -uo pipefail

DOTFILES="${DOTFILES:-$(cd "$(dirname "$0")/.." && pwd)}"
DOT_REAL="$(cd "$DOTFILES" && pwd -P)"

for arg in "$@"; do
  case "$arg" in
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "ERROR: unknown flag: $arg" >&2; exit 1 ;;
  esac
done

OS="$("$DOTFILES/install/detect-os.sh")"

ok()   { printf "  \033[32m✓\033[0m %s\n" "$1"; }
bad()  { printf "  \033[31m✗\033[0m %s\n" "$1"; }
info() { printf "  \033[33m·\033[0m %s\n" "$1"; }

DRIFT=0

# --- symlinks ---------------------------------------------------------------
# A target is "linked" when the leaf OR any ancestor dir is a symlink resolving
# into the repo (stow folds directories). Present-but-not-ours = conflict.
is_ours_link() {
  [[ -L "$1" ]] || return 1
  local r; r="$(readlink -f "$1" 2>/dev/null)" || return 1
  case "$r" in "$DOT_REAL"/*) return 0 ;; *) return 1 ;; esac
}

classify_rel() { # $1 = path relative to $HOME; echoes linked|conflict|missing
  local cur="$HOME" comp; local -a comps
  IFS='/' read -ra comps <<< "$1"
  for comp in "${comps[@]}"; do
    cur="$cur/$comp"
    is_ours_link "$cur" && { echo linked; return; }
  done
  if [[ -e "$HOME/$1" || -L "$HOME/$1" ]]; then echo conflict; else echo missing; fi
}

module_present() { # $1 = module; true if any target currently exists (opted in)
  local f rel
  while IFS= read -r -d '' f; do
    rel="${f#"$DOTFILES/$1"/}"
    [[ -e "$HOME/$rel" || -L "$HOME/$rel" ]] && return 0
  done < <(find "$DOTFILES/$1" -type f -print0 2>/dev/null)
  return 1
}

plan_module() { # $1 = module
  local mod="$1" f rel st linked=0 conflict=0 missing=0 lines=""
  while IFS= read -r -d '' f; do
    rel="${f#"$DOTFILES/$mod"/}"
    st="$(classify_rel "$rel")"
    case "$st" in
      linked)   linked=$((linked + 1)) ;;
      conflict) conflict=$((conflict + 1)); lines="$lines\n        ~/$rel (would back up + link)"; DRIFT=$((DRIFT + 1)) ;;
      missing)  missing=$((missing + 1));  lines="$lines\n        ~/$rel (would link)";          DRIFT=$((DRIFT + 1)) ;;
    esac
  done < <(find "$DOTFILES/$mod" -type f -print0)
  if [[ $((conflict + missing)) -eq 0 ]]; then
    ok "$mod ($linked linked)"
  else
    bad "$mod ($linked linked, $conflict conflict, $missing missing)"
    printf '%b\n' "${lines#\\n}"
  fi
}

echo "==> Plan for $DOT_REAL on $OS (read-only)"
echo ""
echo "Symlinks"
modules=(zsh git tmux starship)
[[ "$OS" == macos || "$OS" == linux ]] && modules+=(kitty)   # kitty skipped on WSL
for mod in "${modules[@]}"; do
  [[ -d "$DOTFILES/$mod" ]] && plan_module "$mod"
done
# nvim is opt-in — only report it once the user has engaged with it.
[[ -d "$DOTFILES/nvim" ]] && module_present nvim && plan_module nvim

# --- packages ---------------------------------------------------------------
plan_dpkg() { # $1 = manifest
  local pkg missing="" total=0 ok_n=0
  while IFS= read -r pkg; do
    pkg="${pkg%%#*}"; pkg="$(printf '%s' "$pkg" | tr -d '[:space:]')"
    [[ -z "$pkg" ]] && continue
    total=$((total + 1))
    if dpkg -s "$pkg" >/dev/null 2>&1; then ok_n=$((ok_n + 1)); else missing="$missing $pkg"; fi
  done < "$1"
  if [[ -z "$missing" ]]; then ok "$ok_n/$total apt packages installed"
  else bad "$ok_n/$total installed; missing:$missing"; DRIFT=$((DRIFT + 1)); fi
}

plan_rpm() { # $1 = manifest
  local pkg missing="" total=0 ok_n=0
  while IFS= read -r pkg; do
    pkg="${pkg%%#*}"; pkg="$(printf '%s' "$pkg" | tr -d '[:space:]')"
    [[ -z "$pkg" ]] && continue
    total=$((total + 1))
    if rpm -q "$pkg" >/dev/null 2>&1; then ok_n=$((ok_n + 1)); else missing="$missing $pkg"; fi
  done < "$1"
  if [[ -z "$missing" ]]; then ok "$ok_n/$total dnf packages installed"
  else bad "$ok_n/$total installed; missing:$missing"; DRIFT=$((DRIFT + 1)); fi
}

echo ""
echo "Packages"
case "$OS" in
  macos)
    if command -v brew >/dev/null 2>&1; then
      if brew bundle check --file "$DOTFILES/install/packages/Brewfile" >/dev/null 2>&1; then
        ok "Brewfile satisfied"
      else
        bad "Brewfile not satisfied (run: dot bootstrap)"
        DRIFT=$((DRIFT + 1))
      fi
    else
      info "brew not found (skipping)"
    fi
    ;;
  linux|wsl)
    if command -v dpkg >/dev/null 2>&1; then
      plan_dpkg "$DOTFILES/install/packages/apt-packages.txt"
    elif command -v rpm >/dev/null 2>&1; then
      plan_rpm "$DOTFILES/install/packages/dnf-packages.txt"
    else
      info "no supported package manager detected (skipping)"
    fi
    ;;
esac

# --- OS defaults (opt-in; informational, never counted as drift) ------------
echo ""
echo "OS defaults"
if [[ "$OS" == macos ]]; then
  match=0; total=3
  [[ "$(defaults read NSGlobalDomain KeyRepeat 2>/dev/null)" == "2" ]] && match=$((match + 1))
  [[ "$(defaults read NSGlobalDomain AppleShowAllExtensions 2>/dev/null)" == "1" ]] && match=$((match + 1))
  [[ "$(defaults read com.apple.dock autohide 2>/dev/null)" == "1" ]] && match=$((match + 1))
  if [[ $match -eq $total ]]; then ok "in sync ($match/$total spot-checks)"
  elif [[ $match -eq 0 ]]; then info "not applied (opt-in; run: dot defaults apply)"
  else info "partial ($match/$total spot-checks)"; fi
else
  info "macOS only; current OS is $OS"
fi

# --- summary ----------------------------------------------------------------
echo ""
if [[ $DRIFT -eq 0 ]]; then
  echo "==> In sync — bootstrap/stow would change nothing."
  exit 0
else
  echo "==> $DRIFT drifted area(s). Run 'dot bootstrap' (or 'dot stow <module>') to converge."
  exit 2
fi
