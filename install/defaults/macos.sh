#!/usr/bin/env bash
set -euo pipefail

SUBCOMMAND="${1:-apply}"
SNAPSHOT_DIR="$HOME/.dotfiles-defaults-backup"
mkdir -p "$SNAPSHOT_DIR"

ENTRIES_TMP=$(mktemp)
trap 'rm -f "$ENTRIES_TMP"' EXIT

snap_entry() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" >> "$ENTRIES_TMP"
}

apply_default() {
  local domain="$1" key="$2" type="$3" value="$4"
  local prev prev_present="true"
  if ! prev=$(defaults read "$domain" "$key" 2>/dev/null); then
    prev=""
    prev_present="false"
  fi
  snap_entry "$domain" "$key" "$type" "$prev" "$prev_present" "$value"
  defaults write "$domain" "$key" "-$type" "$value"
}

apply_all() {
  apply_default NSGlobalDomain KeyRepeat int 2
  apply_default NSGlobalDomain InitialKeyRepeat int 15
  apply_default NSGlobalDomain ApplePressAndHoldEnabled bool false
  apply_default NSGlobalDomain NSAutomaticSpellingCorrectionEnabled bool false
  apply_default NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled bool false
  apply_default NSGlobalDomain NSAutomaticDashSubstitutionEnabled bool false
  apply_default NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled bool false
  apply_default NSGlobalDomain NSAutomaticCapitalizationEnabled bool false

  apply_default NSGlobalDomain AppleShowAllExtensions bool true
  apply_default com.apple.finder AppleShowAllFiles bool true
  apply_default com.apple.finder ShowPathbar bool true
  apply_default com.apple.finder ShowStatusBar bool true
  apply_default com.apple.finder FXDefaultSearchScope string SCcf

  apply_default com.apple.desktopservices DSDontWriteNetworkStores bool true
  apply_default com.apple.desktopservices DSDontWriteUSBStores bool true

  mkdir -p "$HOME/Pictures/Screenshots"
  apply_default com.apple.screencapture location string "$HOME/Pictures/Screenshots"
  apply_default com.apple.screencapture type string png
  apply_default com.apple.screencapture disable-shadow bool true

  apply_default com.apple.dock autohide bool true
  apply_default com.apple.dock autohide-time-modifier float 0.2
  apply_default com.apple.dock show-recents bool false

  apply_default NSGlobalDomain NSNavPanelExpandedStateForSaveMode bool true
  apply_default NSGlobalDomain PMPrintingExpandedStateForPrint bool true
}

write_snapshot() {
  local out="$1" ts="$2"
  python3 - "$ts" "$ENTRIES_TMP" >"$out" <<'PY'
import json, sys
ts = sys.argv[1]
entries = []
with open(sys.argv[2]) as f:
    for line in f:
        parts = line.rstrip("\n").split("\t")
        domain, key, t, prev, present, applied = parts
        entries.append({
            "domain": domain, "key": key, "type": t,
            "previous": (prev if present == "true" else None),
            "applied": applied,
        })
print(json.dumps({"platform": "macos", "timestamp": ts, "entries": entries}, indent=2))
PY
}

case "$SUBCOMMAND" in
  apply)
    if [[ "$(uname -s)" != "Darwin" ]]; then
      echo "ERROR: macos.sh only runs on Darwin (got $(uname -s))" >&2
      exit 1
    fi
    TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    SNAPSHOT="$SNAPSHOT_DIR/${TS//:/-}.json"
    echo "==> Applying macOS defaults (snapshot: $SNAPSHOT)"
    apply_all
    write_snapshot "$SNAPSHOT" "$TS"
    echo "==> Restarting Finder, Dock, SystemUIServer"
    killall Finder Dock SystemUIServer 2>/dev/null || true
    echo "==> Done. Revert with: $0 revert $SNAPSHOT"
    ;;
  revert)
    SNAPSHOT="${2:?usage: $0 revert <snapshot.json>}"
    [[ -f "$SNAPSHOT" ]] || { echo "ERROR: snapshot not found: $SNAPSHOT" >&2; exit 1; }
    echo "==> Reverting from $SNAPSHOT"
    python3 - "$SNAPSHOT" <<'PY' | while IFS=$'\t' read -r domain key type prev present; do
import json, sys
data = json.load(open(sys.argv[1]))
for e in data["entries"]:
    prev = e["previous"]
    print("\t".join([
        e["domain"], e["key"], e["type"],
        "" if prev is None else str(prev),
        "false" if prev is None else "true",
    ]))
PY
      if [[ "$present" == "true" ]]; then
        defaults write "$domain" "$key" "-$type" "$prev"
      else
        defaults delete "$domain" "$key" 2>/dev/null || true
      fi
    done
    killall Finder Dock SystemUIServer 2>/dev/null || true
    echo "==> Reverted."
    ;;
  *)
    echo "usage: $0 [apply|revert <snapshot.json>]" >&2
    exit 2
    ;;
esac
