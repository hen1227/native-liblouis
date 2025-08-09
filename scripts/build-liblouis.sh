#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLED="$ROOT/bundled_tables"
IS_MAC=false
[[ "$(uname -s)" == "Darwin" ]] && IS_MAC=true

banner() {
  echo ""
  echo "============================================================"
  echo "$1"
  echo "============================================================"
  echo ""
}

on_err() {
  echo ""
  echo " Liblouis build failed. Check the logs above."
  exit 1
}
trap on_err ERR

banner " Starting Liblouis builds (Android • iOS • Web)"

echo " These scripts were designed on macOS."
echo "   • Android + Web can build on macOS, Linux, or Windows (WSL)."
echo "   • iOS build **requires macOS + Xcode** and will be skipped otherwise."
echo ""

# --- Check for unicode.dis ---
if [[ ! -f "$BUNDLED/unicode.dis" ]]; then
  echo " '$BUNDLED/unicode.dis' not found."
  echo "   This table is commonly included. You can add it with:"
  echo "     npm run tables:add unicode.dis"
  read -r -p "Continue WITHOUT 'unicode.dis'? [y/N] " yn
  case "$yn" in
    [Yy]* ) echo "→ Continuing without 'unicode.dis'...";;
    * ) echo "Aborting. To add it run: npm run tables:add unicode.dis"; exit 1;;
  esac
fi

# --- Build Android ---
banner "Building: Android"
bash "$ROOT/scripts/build-liblouis-android.sh"
echo "Android build complete."

# --- Build iOS (macOS only) ---
if $IS_MAC; then
  banner "Building: iOS (macOS detected)"
  bash "$ROOT/scripts/build-liblouis-ios.sh"
  echo "iOS build complete."
else
  echo "Skipping iOS: macOS not detected."
  echo "   iOS builds require Xcode's command-line tools on macOS."
fi

# --- Build Web (Emscripten) ---
banner "Building: Web (WASM)"
bash "$ROOT/scripts/build-liblouis-web.sh"
echo "Web build complete."

banner "All requested Liblouis builds finished successfully!"
