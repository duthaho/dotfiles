# --disable-up-arrow preserves existing up-arrow history; Ctrl-R opens atuin.
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi
