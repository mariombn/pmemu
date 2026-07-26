#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MGBA_DIR="$ROOT_DIR/External/mGBA"
BUILD_ROOT="$ROOT_DIR/Build/mGBA"
VENDOR_DIR="$ROOT_DIR/Vendor/mGBA"
XCFRAMEWORK="$VENDOR_DIR/mGBA.xcframework"
CONFIGURATION="${CONFIGURATION:-Release}"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

export DEVELOPER_DIR

if ! command -v cmake >/dev/null 2>&1; then
  echo "error: cmake not found. Install with: brew install cmake" >&2
  exit 1
fi

if [[ ! -d "$MGBA_DIR/.git" && ! -f "$MGBA_DIR/.git" ]]; then
  echo "error: mGBA submodule not found at $MGBA_DIR" >&2
  echo "Run: git submodule update --init --recursive" >&2
  exit 1
fi

COMMON_CMAKE_ARGS=(
  -G Xcode
  -DLIBMGBA_ONLY=ON
  -DBUILD_SHARED=OFF
  -DBUILD_STATIC=ON
  -DBUILD_QT=OFF
  -DBUILD_SDL=OFF
  -DBUILD_GL=OFF
  -DBUILD_GLES2=OFF
  -DBUILD_GLES3=OFF
  -DBUILD_EPOXY=OFF
  -DUSE_LZMA=OFF
  -DUSE_PNG=OFF
  -DUSE_ZLIB=OFF
  -DUSE_SQLITE3=OFF
  -DENABLE_SCRIPTING=OFF
  -DENABLE_DEBUGGERS=OFF
  -DM_CORE_GBA=OFF
  -DM_CORE_GB=ON
)

build_slice() {
  local name="$1"
  local system_name="$2"
  local sdk_name="$3"
  local archs="$4"
  local deployment_target="$5"

  local build_dir="$BUILD_ROOT/$name"
  local sdk_path
  sdk_path="$(xcrun --sdk "$sdk_name" --show-sdk-path)"

  echo "==> Configuring mGBA $name ($sdk_name / $archs)"
  cmake -S "$MGBA_DIR" -B "$build_dir" \
    "${COMMON_CMAKE_ARGS[@]}" \
    -DCMAKE_SYSTEM_NAME="$system_name" \
    -DCMAKE_OSX_SYSROOT="$sdk_path" \
    -DCMAKE_OSX_ARCHITECTURES="$archs" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$deployment_target"

  echo "==> Building mGBA $name"
  cmake --build "$build_dir" --config "$CONFIGURATION" --target mgba
}

prepare_headers() {
  local generated_include_dir="$BUILD_ROOT/ios-simulator/include"
  local headers_dir="$VENDOR_DIR/Headers"

  echo "==> Preparing headers"
  rm -rf "$headers_dir"
  mkdir -p "$headers_dir"

  cp -R "$MGBA_DIR/include/mgba" "$headers_dir/"
  cp -R "$MGBA_DIR/include/mgba-util" "$headers_dir/"

  # CMake generates mgba/flags.h from src/core/flags.h.in.
  if [[ -d "$generated_include_dir" ]]; then
    cp -R "$generated_include_dir/"* "$headers_dir/"
  fi
}

create_xcframework() {
  echo "==> Creating $XCFRAMEWORK"
  rm -rf "$XCFRAMEWORK"
  xcodebuild -create-xcframework \
    -library "$BUILD_ROOT/ios-device/$CONFIGURATION-iphoneos/libmgba.a" -headers "$VENDOR_DIR/Headers" \
    -library "$BUILD_ROOT/ios-simulator/$CONFIGURATION-iphonesimulator/libmgba.a" -headers "$VENDOR_DIR/Headers" \
    -library "$BUILD_ROOT/watchos-device/$CONFIGURATION-watchos/libmgba.a" -headers "$VENDOR_DIR/Headers" \
    -library "$BUILD_ROOT/watchos-simulator/$CONFIGURATION-watchsimulator/libmgba.a" -headers "$VENDOR_DIR/Headers" \
    -output "$XCFRAMEWORK"
}

rm -rf "$BUILD_ROOT" "$XCFRAMEWORK"
mkdir -p "$BUILD_ROOT" "$VENDOR_DIR"

build_slice "ios-device" "iOS" "iphoneos" "arm64" "16.0"
build_slice "ios-simulator" "iOS" "iphonesimulator" "arm64;x86_64" "16.0"
build_slice "watchos-device" "watchOS" "watchos" "arm64;arm64_32" "9.0"
build_slice "watchos-simulator" "watchOS" "watchsimulator" "arm64;x86_64" "9.0"
prepare_headers
create_xcframework

echo "==> Done: $XCFRAMEWORK"
