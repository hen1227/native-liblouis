#!/usr/bin/env bash
set -euo pipefail

LIBLOUIS_TAG="v3.33.0"
ANDROID_API_LEVEL=21  # Minimum API level for modern Android apps
NDK_VERSION="27.0.12077973"

ROOT=$(pwd)
BUILD_DIR="$ROOT/liblouis-build"
SRC_DIR="$BUILD_DIR/liblouis"
OUT_DIR="$ROOT/android/src/main"
JNI_LIBS_DIR="$OUT_DIR/jniLibs"
INCLUDE_DIR="$OUT_DIR/cpp/include"

# Android architectures to build for
ARCHITECTURES=("arm64-v8a" "armeabi-v7a" "x86" "x86_64")

mkdir -p "$BUILD_DIR" "$JNI_LIBS_DIR" "$INCLUDE_DIR"

# ---------- setup Android NDK ----------
echo "Setting up Android NDK..."

# Try to find NDK in common locations
NDK_PATH=""
if [ -n "${ANDROID_NDK_ROOT:-}" ]; then
    NDK_PATH="$ANDROID_NDK_ROOT"
elif [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME/ndk/$NDK_VERSION" ]; then
    NDK_PATH="$ANDROID_HOME/ndk/$NDK_VERSION"
elif [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -d "$ANDROID_SDK_ROOT/ndk/$NDK_VERSION" ]; then
    NDK_PATH="$ANDROID_SDK_ROOT/ndk/$NDK_VERSION"
elif [ -d "$HOME/Android/Sdk/ndk/$NDK_VERSION" ]; then
    NDK_PATH="$HOME/Android/Sdk/ndk/$NDK_VERSION"
else
    # Try to find any NDK version
    if [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME/ndk" ]; then
        NDK_DIRS=("$ANDROID_HOME"/ndk/*)
        if [ ${#NDK_DIRS[@]} -gt 0 ] && [ -d "${NDK_DIRS[0]}" ]; then
            NDK_PATH="${NDK_DIRS[0]}"
            echo "  Using NDK version: $(basename "$NDK_PATH")"
        fi
    elif [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -d "$ANDROID_SDK_ROOT/ndk" ]; then
        NDK_DIRS=("$ANDROID_SDK_ROOT"/ndk/*)
        if [ ${#NDK_DIRS[@]} -gt 0 ] && [ -d "${NDK_DIRS[0]}" ]; then
            NDK_PATH="${NDK_DIRS[0]}"
            echo "  Using NDK version: $(basename "$NDK_PATH")"
        fi
    elif [ -d "$HOME/Android/Sdk/ndk" ]; then
        NDK_DIRS=("$HOME/Android/Sdk/ndk"/*)
        if [ ${#NDK_DIRS[@]} -gt 0 ] && [ -d "${NDK_DIRS[0]}" ]; then
            NDK_PATH="${NDK_DIRS[0]}"
            echo "  Using NDK version: $(basename "$NDK_PATH")"
        fi
    fi
fi

if [ -z "$NDK_PATH" ] || [ ! -d "$NDK_PATH" ]; then
    echo "Android NDK not found. Please install NDK via Android Studio or set ANDROID_NDK_ROOT."
    echo "   Common locations:"
    echo "   - \$ANDROID_HOME/ndk/[version]"
    echo "   - \$ANDROID_SDK_ROOT/ndk/[version]"
    echo "   - \$HOME/Android/Sdk/ndk/[version]"
    exit 1
fi

echo "Found Android NDK at: $NDK_PATH"

# ---------- helper function ----------
build_android_arch() {
    local ARCH=$1
    local TARGET_HOST=$2
    local TOOLCHAIN_PREFIX=$3

    echo "Building for architecture: $ARCH"

    local ARCH_BUILD_DIR="$BUILD_DIR/android-$ARCH"
    local TOOLCHAIN="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        TOOLCHAIN="$NDK_PATH/toolchains/llvm/prebuilt/darwin-x86_64"
    fi

    if [ ! -d "$TOOLCHAIN" ]; then
        echo "Toolchain not found: $TOOLCHAIN"
        exit 1
    fi

    rm -rf "$ARCH_BUILD_DIR"
    mkdir -p "$ARCH_BUILD_DIR"

    export AR="$TOOLCHAIN/bin/llvm-ar"
    export CC="$TOOLCHAIN/bin/${TOOLCHAIN_PREFIX}${ANDROID_API_LEVEL}-clang"
    export CXX="$TOOLCHAIN/bin/${TOOLCHAIN_PREFIX}${ANDROID_API_LEVEL}-clang++"
    export LD="$TOOLCHAIN/bin/ld"
    export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
    export STRIP="$TOOLCHAIN/bin/llvm-strip"
    export READELF="$TOOLCHAIN/bin/llvm-readelf"
    export NM="$TOOLCHAIN/bin/llvm-nm"
    export OBJCOPY="$TOOLCHAIN/bin/llvm-objcopy"
    export OBJDUMP="$TOOLCHAIN/bin/llvm-objdump"

    cd "$SRC_DIR"

    make distclean 2>/dev/null || true
    rm -rf config.cache autom4te.cache

    local CPU_COUNT=4
    if [[ "$OSTYPE" == "darwin"* ]]; then
        CPU_COUNT=$(sysctl -n hw.ncpu)
    else
        CPU_COUNT=$(nproc)
    fi

    # If configure is missing (fresh git checkout), generate it
    if [ ! -x ./configure ]; then
      echo "Generating ./configure via autotools…"
      if [ -x ./autogen.sh ]; then
        ./autogen.sh
      else
        # Fallback if autogen.sh isn't executable/available
        autoreconf -fi
      fi
    fi

    # clean prior attempts safely
    make distclean 2>/dev/null || true
    rm -rf config.cache autom4te.cache

    ./configure \
        --host="$TARGET_HOST" \
        --prefix="$ARCH_BUILD_DIR" \
        --disable-shared \
        --enable-static \
        --disable-tools \
        --disable-tables-check \
        --with-pic \
        ac_cv_func_malloc_0_nonnull=yes \
        ac_cv_func_realloc_0_nonnull=yes \
        CFLAGS="-fPIC -O2 -DANDROID -D__ANDROID_API__=$ANDROID_API_LEVEL" \
        LDFLAGS="-static -Wl,--gc-sections"

    make -j"$CPU_COUNT" && make install

    # Copy static library to jniLibs
    mkdir -p "$JNI_LIBS_DIR/$ARCH"
    cp "$ARCH_BUILD_DIR/lib/liblouis.a" "$JNI_LIBS_DIR/$ARCH/"

    echo "Built $ARCH successfully"
}

# ---------- fetch liblouis source ----------
if [ -d "$SRC_DIR/.git" ]; then
    echo "Checking existing Liblouis repo..."
    cd "$SRC_DIR"
    CURRENT_TAG=$(git describe --tags --exact-match 2>/dev/null || echo "none")
    if [ "$CURRENT_TAG" != "$LIBLOUIS_TAG" ]; then
        echo "Existing Liblouis is at $CURRENT_TAG, switching to $LIBLOUIS_TAG..."
        git fetch --depth 1 origin tag "$LIBLOUIS_TAG"
        git checkout "$LIBLOUIS_TAG"
        # Re-run autogen after checkout
        ./autogen.sh
    else
        echo "Liblouis already at $LIBLOUIS_TAG"
    fi
else
    echo "Cloning Liblouis $LIBLOUIS_TAG..."
    rm -rf "$SRC_DIR"
    git clone --depth 1 --branch "$LIBLOUIS_TAG" https://github.com/liblouis/liblouis.git "$SRC_DIR"
    cd "$SRC_DIR"
    echo "Running autogen.sh..."
    ./autogen.sh
fi

# ---------- build for each architecture ----------
for arch in "${ARCHITECTURES[@]}"; do
    case $arch in
        "arm64-v8a")
            build_android_arch "$arch" "aarch64-linux-android" "aarch64-linux-android"
            ;;
        "armeabi-v7a")
            build_android_arch "$arch" "arm-linux-androideabi" "armv7a-linux-androideabi"
            ;;
        "x86")
            build_android_arch "$arch" "i686-linux-android" "i686-linux-android"
            ;;
        "x86_64")
            build_android_arch "$arch" "x86_64-linux-android" "x86_64-linux-android"
            ;;
    esac
done

# ---------- copy headers (after all builds are complete) ----------
echo "Copying liblouis headers..."
# Use the first architecture's build to copy headers (they're the same for all)
FIRST_ARCH_BUILD_DIR="$BUILD_DIR/android-${ARCHITECTURES[0]}"
if [ -d "$FIRST_ARCH_BUILD_DIR/include" ]; then
    rm -rf "$INCLUDE_DIR"
    mkdir -p "$INCLUDE_DIR"
    cp -R "$FIRST_ARCH_BUILD_DIR/include/"* "$INCLUDE_DIR/"
    echo "Copied headers to $INCLUDE_DIR"
else
    echo "Headers not found at $FIRST_ARCH_BUILD_DIR/include"
    exit 1
fi

# ---------- copy braille tables ----------
echo "Copying braille tables..."
TABLES_SRC="$ROOT/bundled_tables"
TABLES_DEST="$OUT_DIR/assets/tables"

if [ -d "$TABLES_SRC" ]; then
    rm -rf "$TABLES_DEST"
    mkdir -p "$TABLES_DEST"
    cp -R "$TABLES_SRC"/* "$TABLES_DEST/"
    echo "Copied braille tables to $TABLES_DEST"
else
    # Try to copy from liblouis source if bundled_tables doesn't exist
    LIBLOUIS_TABLES="$SRC_DIR/tables"
    if [ -d "$LIBLOUIS_TABLES" ]; then
        rm -rf "$TABLES_DEST"
        mkdir -p "$TABLES_DEST"
        cp "$LIBLOUIS_TABLES"/*.{tbl,utb,ctb,cti,cto,dis} "$TABLES_DEST/" 2>/dev/null || true
        echo "Copied braille tables from liblouis source to $TABLES_DEST"
    else
        echo " Warning: Braille tables not found at $TABLES_SRC or $LIBLOUIS_TABLES"
    fi
fi

echo ""
echo "Android build complete!"
echo "Static libraries copied to: $JNI_LIBS_DIR"
echo "Headers copied to: $INCLUDE_DIR"
echo "Braille tables copied to: $TABLES_DEST"
echo ""
echo "Library sizes:"
for arch in "${ARCHITECTURES[@]}"; do
    if [ -f "$JNI_LIBS_DIR/$arch/liblouis.a" ]; then
        size=$(du -h "$JNI_LIBS_DIR/$arch/liblouis.a" | cut -f1)
        echo "  $arch: $size"
    fi
done
