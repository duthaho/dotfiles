# Heavy completions loaded lazily — only when the binary is actually present.
# Each block is wrapped so it costs near-zero at shell startup.

if [[ $commands[kubectl] ]]; then
  source <(kubectl completion zsh 2>/dev/null) || true
fi

if [[ $commands[docker] ]]; then
  source <(docker completion zsh 2>/dev/null) || true
fi

if [[ $commands[gh] ]]; then
  eval "$(gh completion -s zsh 2>/dev/null)" || true
fi
