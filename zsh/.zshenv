# .zshenv — sourced on every zsh invocation, including non-interactive.
# Put env vars only; no aliases or interactive config.

export EDITOR=nvim
export VISUAL=nvim
export PAGER=less
export LESS='-R -F -X'

# PATH additions — guard each so it appears only once
typeset -U path PATH
for dir in "$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/bin"; do
  [[ -d "$dir" ]] && path=("$dir" $path)
done
export PATH
