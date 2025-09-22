#!/usr/bin/env bash
set -euo pipefail

SRC_COPY="${BUILD_ROOT}/opus-src"
rm -rf "${SRC_COPY}"
rsync -a --delete --exclude=".git" "${OPUS_DIR}/" "${SRC_COPY}/"

ROOT_DIR="$(cd "$(dirname "$0")/.."; pwd)"
OPUS_DIR="${SRC_COPY}"
OUT_DIR="${ROOT_DIR}/ios/opus"                 # where Opus.xcframework will be written
BUILD_ROOT="${ROOT_DIR}/build/opus"
MIN_IOS="12.0"

# If building from git checkout, autogen.sh needs GNU libtool (called glibtool on macOS)
export LIBTOOLIZE="${LIBTOOLIZE:-glibtoolize}"

mkdir -p "${BUILD_ROOT}" "${OUT_DIR}"

configure_build () {
  local SDK_NAME="$1"      # iphoneos | iphonesimulator
  local ARCH="$2"          # arm64 | x86_64 (optional)
  local HOST="$3"          # aarch64-apple-darwin | x86_64-apple-darwin
  local MIN_FLAG="$4"      # -miphoneos-version-min=... OR -mios-simulator-version-min=...
  local EXTRA_CFLAGS="$5"  # any extra cflags (usually empty)

  local SDK_PATH
  SDK_PATH="$(xcrun --sdk "${SDK_NAME}" --show-sdk-path)"
  local CC_BIN
  CC_BIN="$(xcrun --sdk "${SDK_NAME}" -f clang)"

  local BUILD_DIR="${BUILD_ROOT}/${SDK_NAME}-${ARCH}"
  rm -rf "${BUILD_DIR}"
  mkdir -p "${BUILD_DIR}"
  pushd "${BUILD_DIR}" >/dev/null

  # Generate configure if needed
  if [[ ! -f "${OPUS_DIR}/configure" && -f "${OPUS_DIR}/autogen.sh" ]]; then
    (cd "${OPUS_DIR}" && ./autogen.sh)
  fi

  # IMPORTANT: --host=aarch64-apple-darwin for arm64, not arm-apple-darwin
  # This prevents pulling in ARMv7 GNU .S files (your error).
  "${OPUS_DIR}/configure" \
    --host="${HOST}" \
    --disable-shared --enable-static \
    --with-pic \
    CC="${CC_BIN}" \
    CFLAGS="-isysroot ${SDK_PATH} -arch ${ARCH} -O3 -fvisibility=hidden ${MIN_FLAG} ${EXTRA_CFLAGS}" \
    LDFLAGS="-isysroot ${SDK_PATH} -arch ${ARCH}"

  # If you still hit assembler issues, uncomment the next line to force pure C:
  # sed -i '' 's/^\(HAVE_ARM_ASM\)=1/\1=0/' config.status || true

  make -j"$(sysctl -n hw.ncpu)"
  popd >/dev/null
}

# 1) Build device (arm64, aarch64-apple-darwin)
configure_build iphoneos arm64 aarch64-apple-darwin "-miphoneos-version-min=${MIN_IOS}" ""

# 2) Build simulator (arm64, aarch64-apple-darwin)
configure_build iphonesimulator arm64 aarch64-apple-darwin "-mios-simulator-version-min=${MIN_IOS}" ""

# (Optional) add Intel simulator if teammates use Intel Macs:
# configure_build iphonesimulator x86_64 x86_64-apple-darwin "-mios-simulator-version-min=${MIN_IOS}" ""
# Then fatten the sim lib:
# SIM_FAT="${BUILD_ROOT}/iphonesimulator-fat/libopus.a"
# lipo -create \
#   "${BUILD_ROOT}/iphonesimulator-arm64/.libs/libopus.a" \
#   "${BUILD_ROOT}/iphonesimulator-x86_64/.libs/libopus.a" \
#   -output "${SIM_FAT}"
# SIM_LIB="${SIM_FAT}"

# Using arm64 simulator slice only:
SIM_LIB="${BUILD_ROOT}/iphonesimulator-arm64/.libs/libopus.a"
DEV_LIB="${BUILD_ROOT}/iphoneos-arm64/.libs/libopus.a"

# 3) Create XCFramework
rm -rf "${OUT_DIR}/Opus.xcframework"
xcodebuild -create-xcframework \
  -library "${DEV_LIB}" -headers "${OPUS_DIR}/include" \
  -library "${SIM_LIB}" -headers "${OPUS_DIR}/include" \
  -output "${OUT_DIR}/Opus.xcframework"

# 4) Show slices
echo "=== XCFramework slices ==="
find "${OUT_DIR}/Opus.xcframework" -name "*.a" -maxdepth 3 -print -exec file {} \;

echo "✅ Built ${OUT_DIR}/Opus.xcframework"