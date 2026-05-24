#!/usr/bin/env bash
# detect-os.sh — echoes one of: macos | linux | wsl
# Exits 1 if the OS is none of these.

set -euo pipefail

case "$(uname -s)" in
  Darwin)
    echo "macos"
    ;;
  Linux)
    if grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null; then
      echo "wsl"
    else
      echo "linux"
    fi
    ;;
  *)
    echo "ERROR: unsupported OS: $(uname -s)" >&2
    exit 1
    ;;
esac
