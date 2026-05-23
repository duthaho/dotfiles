# fzf — fuzzy finder integration. Only wires up if fzf is installed.

if command -v fzf >/dev/null 2>&1; then
  # Source fzf's shell integration if it exists in the usual places
  for f in \
    /opt/homebrew/opt/fzf/shell/completion.zsh \
    /opt/homebrew/opt/fzf/shell/key-bindings.zsh \
    /usr/share/doc/fzf/examples/key-bindings.zsh \
    /usr/share/fzf/key-bindings.zsh; do
    [[ -r "$f" ]] && source "$f"
  done

  # Use fd if present — respects .gitignore by default
  if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  fi
fi
