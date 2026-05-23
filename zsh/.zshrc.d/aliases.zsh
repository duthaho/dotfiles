# Navigation
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

# ls → eza if installed, else fall back
if command -v eza >/dev/null 2>&1; then
  alias ls="eza --group-directories-first"
  alias ll="eza -lah --group-directories-first"
  alias tree="eza --tree"
elif command -v exa >/dev/null 2>&1; then
  alias ls="exa --group-directories-first"
  alias ll="exa -lah --group-directories-first"
else
  alias ll="ls -lah"
fi

# Editor / git / k8s
alias vim="nvim"
alias g="lazygit"
alias gs="git status -sb"
alias gp="git push"
alias gl="git log --oneline --graph --decorate -20"
alias k="kubectl"

# Guardrails — interactive prompts on destructive ops
alias rm="rm -i"
alias cp="cp -i"
alias mv="mv -i"
