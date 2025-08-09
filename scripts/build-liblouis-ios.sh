#!/usr/bin/env bash
set -euo pipefail

LIBLOUIS_TAG="v3.33.0"
SDK_MIN=13.0

ROOT=$(pwd)
BUNDLED_TABLES_DIR="$ROOT/bundled_tables"
BUILD_DIR="$ROOT/liblouis-build"
OUT_DIR="$ROOT/ios"
SRC_DIR="$BUILD_DIR/liblouis"

IOS_TABLES_ASSETS_DIR="$OUT_DIR/liblouis_assets/tables"

mkdir -p "$BUILD_DIR" "$OUT_DIR"

# ---------- helper ----------
build_one () {
  local ARCH=$1 SDK=$2 OUT=$3 HOST=$4
  local PREFIX="$BUILD_DIR/$OUT"

  CC="$(xcrun -sdk $SDK -find clang)"
  CFLAGS="-arch $ARCH -isysroot $(xcrun --sdk $SDK --show-sdk-path)"
  [[ $SDK == iphonesimulator ]] \
      && CFLAGS+=" -mios-simulator-version-min=${SDK_MIN}" \
      || CFLAGS+=" -mios-version-min=${SDK_MIN}"

  ./configure --host="$HOST" --prefix="$PREFIX" \
              CFLAGS="$CFLAGS" LDFLAGS="$CFLAGS"
  make -j"$(sysctl -n hw.ncpu)" && make install && make distclean
}

# ---------- fetch source ----------
rm -rf "$SRC_DIR"
git clone --depth 1 --branch "$LIBLOUIS_TAG" https://github.com/liblouis/liblouis.git "$SRC_DIR"
cd "$SRC_DIR" && ./autogen.sh

# ---------- build targets ----------
build_one arm64   iphoneos        ios-arm64            arm-apple-darwin
build_one arm64   iphonesimulator sim-arm64            arm-apple-darwin
build_one x86_64  iphonesimulator sim-x86_64           x86_64-apple-darwin

# ---------- merge simulator slices ----------
SIM_FAT_DIR="$BUILD_DIR/sim-fat"
mkdir -p "$SIM_FAT_DIR/lib"
lipo -create \
     "$BUILD_DIR/sim-arm64/lib/liblouis.a" \
     "$BUILD_DIR/sim-x86_64/lib/liblouis.a" \
     -output "$SIM_FAT_DIR/lib/liblouis.a"
cp -R "$BUILD_DIR/sim-arm64/include" "$SIM_FAT_DIR/include"

# ---------- create XCFramework ----------
rm -rf "$OUT_DIR/liblouis.xcframework"
xcodebuild -create-xcframework \
   -library "$BUILD_DIR/ios-arm64/lib/liblouis.a"  -headers "$BUILD_DIR/ios-arm64/include" \
   -library "$SIM_FAT_DIR/lib/liblouis.a"          -headers "$SIM_FAT_DIR/include" \
   -output "$OUT_DIR/liblouis.xcframework"

# ---------- copy LICENSE ----------
cp "$ROOT/LICENSE" "$OUT_DIR/LICENSE"

# ---------- copy braille tables (iOS assets) ----------
echo "📋 Copying braille tables to iOS assets..."
rm -rf "$IOS_TABLES_ASSETS_DIR"
mkdir -p "$IOS_TABLES_ASSETS_DIR"

if [ -d "$BUNDLED_TABLES_DIR" ]; then
  cp -R "$BUNDLED_TABLES_DIR/"* "$IOS_TABLES_ASSETS_DIR/" 2>/dev/null || true
  echo "Copied from $BUNDLED_TABLES_DIR → $IOS_TABLES_ASSETS_DIR"
else
  LIBLOUIS_TABLES="$SRC_DIR/tables"
  if [ -d "$LIBLOUIS_TABLES" ]; then
    cp "$LIBLOUIS_TABLES"/*.{tbl,utb,ctb,cti,cto,dis} "$IOS_TABLES_ASSETS_DIR/" 2>/dev/null || true
    echo "Copied from liblouis source tables → $IOS_TABLES_ASSETS_DIR"
  else
    echo "⚠️  No tables found at $BUNDLED_TABLES_DIR or $LIBLOUIS_TABLES"
  fi
fi

echo "iOS build complete: $OUT_DIR/liblouis.xcframework"
echo "Tables at: $IOS_TABLES_ASSETS_DIR"
