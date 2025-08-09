#!/usr/bin/env bash
set -euo pipefail

LIBLOUIS_TAG="v3.33.0"
ROOT=$(pwd)
BUILD_DIR="$ROOT/liblouis-build"
SRC_DIR="$BUILD_DIR/liblouis"
OUT_DIR="$ROOT/src/liblouis-web"
EMSDK_DIR="$BUILD_DIR/emsdk"

mkdir -p "$BUILD_DIR" "$OUT_DIR"

# ---------- setup emscripten ----------
echo "Checking for emsdk..."

if [ -z "$(command -v emcc)" ]; then
  if [ ! -f "$EMSDK_DIR/emsdk_env.sh" ]; then
    echo "Installing emsdk locally to $EMSDK_DIR"
    git clone https://github.com/emscripten-core/emsdk.git "$EMSDK_DIR"
    cd "$EMSDK_DIR"
    ./emsdk install latest
    ./emsdk activate latest
  fi

  echo "Activating emsdk..."
  source "$EMSDK_DIR/emsdk_env.sh"
else
  echo "emcc already available: $(which emcc)"
fi

# ---------- fetch liblouis ----------
if [ -d "$SRC_DIR/.git" ]; then
  echo "Checking existing Liblouis repo..."
  cd "$SRC_DIR"
  CURRENT_TAG=$(git describe --tags --exact-match 2>/dev/null || echo "none")
  if [ "$CURRENT_TAG" != "$LIBLOUIS_TAG" ]; then
    echo "Existing Liblouis is at $CURRENT_TAG, switching to $LIBLOUIS_TAG..."
    git fetch --depth 1 origin tag "$LIBLOUIS_TAG"
    git checkout "$LIBLOUIS_TAG"
  else
    echo "Liblouis already at $LIBLOUIS_TAG"
  fi
else
  echo "Cloning Liblouis $LIBLOUIS_TAG..."
  git clone --depth 1 --branch "$LIBLOUIS_TAG" https://github.com/liblouis/liblouis.git "$SRC_DIR"
  cd "$SRC_DIR"
fi


cd "$SRC_DIR"
./autogen.sh
emconfigure ./configure --disable-shared --enable-debug

echo "Building with emmake..."
emmake make -j"$(nproc)"

echo "Compiling to WebAssembly..."
#emcc ./liblouis/.libs/liblouis.a \
#  -s MODULARIZE=1 \
#  -s EXPORT_NAME=NativeLiblouis \
#  -s ENVIRONMENT='web' \
#  -s EXPORTED_FUNCTIONS="[
#    '_lou_translateString',
#    '_lou_backTranslateString',
#    '_lou_setDataPath',
#    '_lou_getTable',
#    '_malloc',
#    '_free'
#  ]" \
#  -s EXPORTED_RUNTIME_METHODS="[
#    'ccall',
#    'cwrap',
#    'FS',
#    'UTF16ToString',
#    'stringToUTF16',
#    'allocateUTF8',
#    'setValue',
#    'getValue',
#    'HEAPU16',
#    'HEAPU8'
#  ]" \
#  -s ALLOW_MEMORY_GROWTH=1 \
#  -s STACK_SIZE=1MB \
#  --no-entry \
#  -s STANDALONE_WASM=0 \
#  -o "$OUT_DIR/liblouis.js" \
#  -s SINGLE_FILE=1 \
#  -s ASSERTIONS=2 \
#  -s SAFE_HEAP=1 \
#  --embed-file "$ROOT/bundled_tables@/tables"
# #  -s INITIAL_MEMORY=256MB \
# #  -s TOTAL_MEMORY=536870912 \

emcc ./liblouis/.libs/liblouis.a \
  -s MODULARIZE=1 \
  -s EXPORT_NAME=NativeLiblouis \
  -s ENVIRONMENT='web' \
  -s EXPORTED_FUNCTIONS="[
    '_lou_translateString',
    '_lou_backTranslateString',
    '_lou_setDataPath',
    '_lou_getTable',
    '_malloc',
    '_free'
  ]" \
  -s EXPORTED_RUNTIME_METHODS="[
    'ccall',
    'cwrap',
    'FS',
    'UTF16ToString',
    'stringToUTF16',
    'allocateUTF8',
    'setValue',
    'getValue',
    'HEAPU16',
    'HEAPU8'
  ]" \
  -s ALLOW_MEMORY_GROWTH=1 \
  -s STACK_SIZE=1MB \
  -s SINGLE_FILE=1 \
  --no-entry \
  -O3 \
  --closure 1 \
  -o "$OUT_DIR/liblouis.js" \
  --embed-file "$ROOT/bundled_tables@/tables"

echo "Web build complete: $OUT_DIR/liblouis.js + .wasm"
