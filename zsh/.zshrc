# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
if [[ -d "$ZSH" ]]; then
  ZSH_THEME=""   # Starship handles the prompt
  plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
  source "$ZSH/oh-my-zsh.sh"
fi

# Library fragments — stow places zsh/.zshrc.d/ at ~/.zshrc.d/
DOTFILES_LIB="$HOME/.zshrc.d"
if [[ -d "$DOTFILES_LIB" ]]; then
  for f in "$DOTFILES_LIB"/*.zsh(N); do
    source "$f"
  done
fi

# Starship prompt
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# Machine-local sidecars (never tracked)
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
[[ -f "$HOME/.env.local"   ]] && { set -a; source "$HOME/.env.local"; set +a; }

# Add npm global bin to PATH if it exists
if [[ -d "$HOME/.npm-global/bin" ]]; then
  export PATH="$HOME/.npm-global/bin:$PATH"
fi
. "$HOME/.atuin/bin/env"

eval "$(atuin init zsh)"
