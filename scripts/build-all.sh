#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLED="$ROOT/bundled_tables"
IS_MAC=false
[[ "$(uname -s)" == "Darwin" ]] && IS_MAC=true

banner(){ echo -e "\n============================================================\n$1\n============================================================\n"; }
on_err(){ echo -e "\n Liblouis build failed. Check the logs above."; exit 1; }
trap on_err ERR

banner "Starting Liblouis builds (Android • iOS • Web)"

echo "These scripts were designed on macOS."
echo "  • Android + Web can build on macOS, Linux, or Windows (WSL)."
echo "  • iOS build requires macOS + Xcode and will be skipped otherwise."
echo ""

# unicode.dis heads-up (non-blocking)
if [[ ! -f "$BUNDLED/unicode.dis" ]]; then
  echo "Note: '$BUNDLED/unicode.dis' not found. Add it with:"
  echo "  npm run tables:add unicode.dis"

  if prompt="Do you want to continue without it? (y/N) "; read -r -n 1 -p "$prompt"; then
    echo ""
  else
    echo -e "\nExiting build process. Add unicode.dis first."
    exit 1
  fi
fi

# Android
banner "Building: Android"
bash "$ROOT/scripts/build-liblouis-android.sh"
echo "Android build complete."

# iOS
if $IS_MAC; then
  banner "Building: iOS (macOS detected)"
  bash "$ROOT/scripts/build-liblouis-ios.sh"
  echo "iOS build complete."
else
  echo "Skipping iOS: macOS not detected. (Requires Xcode CLI tools.)"
fi

# Web
banner "Building: Web (WASM)"
bash "$ROOT/scripts/build-liblouis-web.sh"
echo "Web build complete."

banner "All Liblouis builds finished successfully!"
