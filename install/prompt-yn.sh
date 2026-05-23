#!/usr/bin/env bash
# prompt-yn.sh — usage: prompt-yn.sh "Message?"
# Returns exit 0 for yes, 1 for no. Default is no (empty input → no).

set -euo pipefail

read -r -p "$1 [y/N]: " response
case "$response" in
  [yY]|[yY][eE][sS]) exit 0 ;;
  *) exit 1 ;;
esac
