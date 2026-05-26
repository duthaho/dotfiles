#!/usr/bin/env bash
set -euo pipefail

GITCONFIG_LOCAL="$HOME/.gitconfig.local"
ZSHRC_LOCAL="$HOME/.zshrc.local"

if [[ -f "$GITCONFIG_LOCAL" && -f "$ZSHRC_LOCAL" ]]; then
  echo "==> Identity sidecars already present, skipping"
  exit 0
fi

echo "==> Seeding identity (writes to ~/.gitconfig.local and ~/.zshrc.local)"

if [[ -n "${NON_INTERACTIVE:-}" ]]; then
  if [[ -z "${GIT_USER_NAME:-}" || -z "${GIT_USER_EMAIL:-}" ]]; then
    echo "ERROR: NON_INTERACTIVE set but GIT_USER_NAME or GIT_USER_EMAIL missing" >&2
    exit 1
  fi
  git_name="$GIT_USER_NAME"
  git_email="$GIT_USER_EMAIL"
  gh_handle="${GH_HANDLE:-}"
  echo "  (using GIT_USER_NAME / GIT_USER_EMAIL from environment)"
else
  read -r -p "Git user.name : " git_name
  read -r -p "Git user.email: " git_email
  read -r -p "GitHub handle (optional, press enter to skip): " gh_handle
fi

if [[ ! -f "$GITCONFIG_LOCAL" ]]; then
  cat > "$GITCONFIG_LOCAL" <<EOF
[user]
    name = $git_name
    email = $git_email
EOF
  if [[ -n "$gh_handle" ]]; then
    cat >> "$GITCONFIG_LOCAL" <<EOF
[github]
    user = $gh_handle
EOF
  fi
  chmod 600 "$GITCONFIG_LOCAL"
  echo "==> Wrote $GITCONFIG_LOCAL"
fi

if [[ ! -f "$ZSHRC_LOCAL" ]]; then
  cat > "$ZSHRC_LOCAL" <<'EOF'
# Personal/machine-local zsh config. Add exports, aliases, paths, etc.
EOF
  echo "==> Wrote $ZSHRC_LOCAL"
fi
