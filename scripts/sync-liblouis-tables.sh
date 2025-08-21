#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLED="$ROOT/bundled_tables"
ANDROID_TABLES_DIR="$ROOT/android/src/main/assets/tables"
IOS_TABLES_DIR="$ROOT/ios/liblouis_assets/tables"
IS_MAC=false
[[ "$(uname -s)" == "Darwin" ]] && IS_MAC=true

SKIP_WEB=false
for arg in "$@"; do
  case "$arg" in
    --skip-web|-w) SKIP_WEB=true ;;
    --help|-h)
      echo "Usage: $(basename "$0") [--skip-web|-w]"
      exit 0
      ;;
  esac
done

banner() { echo -e "\n============================================================\n$1\n============================================================\n"; }
have() { command -v "$1" >/dev/null 2>&1; }
sync_dir() {
  local src="$1" dst="$2"
  mkdir -p "$dst"
  if have rsync; then
    rsync -a --delete "$src"/ "$dst"/
  else
    rm -rf "$dst"/* 2>/dev/null || true
    # -p to preserve modes/times; -R not needed; -a may not exist on all cp variants
    cp -r "$src"/. "$dst"/
  fi
}

on_err(){ echo -e "\n Sync failed. Check logs above."; exit 1; }
trap on_err ERR

banner "Syncing Liblouis tables (Android • iOS) and rebuilding Web"

# Optional but helpful sanity check
if [[ ! -f "$BUNDLED/unicode.dis" ]]; then
  echo "Note: '$BUNDLED/unicode.dis' not found. Add it with:"
  echo "  npm run tables:add unicode.dis"
fi

# Android tables
banner "Android: syncing tables → $ANDROID_TABLES_DIR"
sync_dir "$BUNDLED" "$ANDROID_TABLES_DIR"
echo "Android tables synced."

# iOS tables (copy only; no native rebuild)
if $IS_MAC; then
  banner "iOS: syncing tables → $IOS_TABLES_DIR"
  sync_dir "$BUNDLED" "$IOS_TABLES_DIR"
  echo "iOS tables synced."
else
  echo "Skipping iOS table sync (not macOS). You can still copy files manually if needed."
fi

# Web (rebuild because tables are embedded)
if ! $SKIP_WEB; then
  banner "Web: rebuilding (tables embedded)"
  bash "$ROOT/scripts/build-liblouis-web.sh"
  echo "Web build complete."
else
  echo "Skipping Web rebuild (--skip-web)."
fi

banner "Done syncing tables."
