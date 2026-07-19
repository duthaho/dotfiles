#!/usr/bin/env bash
# update.sh — pull the repo, re-stow default modules, and flag when a pull
# brought in package-manifest changes (which re-stowing does NOT install).
#
# The friction this removes: after a pull that edits install/packages/*, you had
# to KNOW to re-run bootstrap. Now update tells you — and offers to do it — then
# runs doctor so you end on a known-good state.
#
# Usage:
#   update.sh                 # pull + re-stow + notice + doctor
#   update.sh --no-doctor     # skip the closing health check
#
# Env: NON_INTERACTIVE=1 suppresses the bootstrap prompt (prints a notice only).

set -euo pipefail

DOTFILES="${DOTFILES:-$(cd "$(dirname "$0")/.." && pwd)}"

RUN_DOCTOR=1
for arg in "$@"; do
  case "$arg" in
    --no-doctor) RUN_DOCTOR=0 ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "ERROR: unknown flag: $arg" >&2; exit 2 ;;
  esac
done

# No TTY on stdin (CI, piped) → nobody can answer a prompt.
# DOT_UPDATE_FORCE_INTERACTIVE=1 lets tests drive the prompt via a pipe.
NON_INTERACTIVE="${NON_INTERACTIVE:-0}"
if [[ "$NON_INTERACTIVE" != "1" && "${DOT_UPDATE_FORCE_INTERACTIVE:-0}" != "1" ]] && ! [ -t 0 ]; then
  NON_INTERACTIVE=1
fi

cd "$DOTFILES"

before="$(git rev-parse HEAD)"
echo "==> git pull --ff-only"
git pull --ff-only
after="$(git rev-parse HEAD)"

# 2. Re-stow the default modules (does not install packages).
echo "==> re-stow default modules"
"$DOTFILES/install/stow-modules.sh"

# 3. Did the pull change any package manifest?
manifests_changed() { # $1 = before, $2 = after
  [[ "$1" == "$2" ]] && return 1
  git diff --name-only "$1" "$2" -- install/packages/ | grep -q .
}

if manifests_changed "$before" "$after"; then
  echo ""
  echo "==> Package manifests changed in this pull:"
  git diff --name-only "$before" "$after" -- install/packages/ | sed 's/^/      /'
  echo "    Re-stowing does NOT install packages — a bootstrap does."
  if [[ "$NON_INTERACTIVE" == "1" ]]; then
    echo "    Run: dot bootstrap"
  elif "$DOTFILES/install/prompt-yn.sh" "Run 'dot bootstrap' now to install them?"; then
    exec "$DOTFILES/bootstrap.sh"
  else
    echo "    Skipped. Run 'dot bootstrap' when ready."
  fi
elif [[ "$before" == "$after" ]]; then
  echo "==> Already up to date."
fi

# 4. Close on a known-good state.
if [[ "$RUN_DOCTOR" == "1" ]]; then
  echo ""
  echo "==> doctor"
  exec "$DOTFILES/doctor.sh"
fi
