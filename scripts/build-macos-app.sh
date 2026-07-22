#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ROOT="${BUILD_ROOT:-$ROOT_DIR/.build/macos}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
DOWNLOAD_DIR="$BUILD_ROOT/downloads"
STAGING_DIR="$BUILD_ROOT/staging"
APP_NAME="Super Mario 63.app"
APP_DIR="$DIST_DIR/$APP_NAME"
ZIP_PATH="$DIST_DIR/Super Mario 63-macOS-arm64.zip"

RUFFLE_RELEASE="nightly-2026-07-19"
RUFFLE_ARCHIVE="ruffle-nightly-2026_07_19-macos-universal.tar.gz"
RUFFLE_URL="https://github.com/ruffle-rs/ruffle/releases/download/$RUFFLE_RELEASE/$RUFFLE_ARCHIVE"
RUFFLE_SHA256="99098da3908a60c67f0dc26ceb87701981c061df2e84e501505ae96b3ad1886a"

SOURCE_SWF="$ROOT_DIR/Publish/Super_Mario_63_2010.swf"
ARCHIVE_PATH="$DOWNLOAD_DIR/$RUFFLE_ARCHIVE"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "error: the macOS app must be built on macOS" >&2
    exit 1
fi

if [[ ! -f "$SOURCE_SWF" ]]; then
    echo "error: game movie not found at $SOURCE_SWF" >&2
    exit 1
fi

mkdir -p "$DOWNLOAD_DIR" "$DIST_DIR"

archive_is_valid() {
    [[ -f "$ARCHIVE_PATH" ]] && \
        [[ "$(shasum -a 256 "$ARCHIVE_PATH" | awk '{print $1}')" == "$RUFFLE_SHA256" ]]
}

if ! archive_is_valid; then
    rm -f "$ARCHIVE_PATH"
    echo "Downloading pinned Ruffle runtime ($RUFFLE_RELEASE)..."
    curl --fail --location --retry 3 --output "$ARCHIVE_PATH" "$RUFFLE_URL"
fi

if ! archive_is_valid; then
    echo "error: Ruffle archive checksum does not match $RUFFLE_SHA256" >&2
    exit 1
fi

rm -rf "$STAGING_DIR" "$APP_DIR"
mkdir -p "$STAGING_DIR" "$MACOS_DIR" "$RESOURCES_DIR"
tar -xzf "$ARCHIVE_PATH" -C "$STAGING_DIR"

echo "Compiling Apple Silicon launcher..."
xcrun swiftc \
    -O \
    -whole-module-optimization \
    -target arm64-apple-macos13.0 \
    "$ROOT_DIR/macos/Launcher/main.swift" \
    -o "$MACOS_DIR/SuperMario63"

echo "Preparing native Metal runtime and game data..."
lipo \
    "$STAGING_DIR/Ruffle.app/Contents/MacOS/ruffle" \
    -thin arm64 \
    -output "$RESOURCES_DIR/RuffleRuntime"
chmod 755 "$RESOURCES_DIR/RuffleRuntime"
cp "$SOURCE_SWF" "$RESOURCES_DIR/Super Mario 63.swf"
cp "$ROOT_DIR/macos/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/macos/THIRD_PARTY_NOTICES.md" "$RESOURCES_DIR/THIRD_PARTY_NOTICES.md"
cp "$STAGING_DIR/LICENSE.md" "$RESOURCES_DIR/RUFFLE_LICENSE.md"

echo "Generating application icon..."
ICON_TOOL="$BUILD_ROOT/IconGenerator"
ICON_MASTER="$BUILD_ROOT/AppIcon-1024.png"
ICONSET_DIR="$BUILD_ROOT/AppIcon.iconset"
xcrun swiftc -O "$ROOT_DIR/macos/Tools/IconGenerator.swift" -o "$ICON_TOOL"
"$ICON_TOOL" "$ICON_MASTER"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

make_icon() {
    local pixels="$1"
    local filename="$2"
    sips --resampleHeightWidth "$pixels" "$pixels" "$ICON_MASTER" \
        --out "$ICONSET_DIR/$filename" >/dev/null
}

make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
cp "$ICON_MASTER" "$ICONSET_DIR/icon_512x512@2x.png"
iconutil --convert icns --output "$RESOURCES_DIR/AppIcon.icns" "$ICONSET_DIR"

SIGNING_IDENTITY="${CODE_SIGN_IDENTITY:--}"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    echo "Applying an ad-hoc local signature..."
    # Ruffle's downloaded slice retains its upstream sandbox signature. Once it
    # lives in our bundle it must receive a fresh signature or macOS will kill it
    # before main() because the original signature belongs to another app.
    codesign --force --sign - "$RESOURCES_DIR/RuffleRuntime"
    codesign --force --deep --sign - "$APP_DIR"
else
    echo "Signing with identity: $SIGNING_IDENTITY"
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" \
        "$RESOURCES_DIR/RuffleRuntime"
    codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_DIR"
fi

"$ROOT_DIR/scripts/verify-macos-app.sh" "$APP_DIR"

echo "Creating distributable archive..."
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

echo
echo "Built $APP_DIR"
echo "Archive: $ZIP_PATH"
echo "Run it with: open \"$APP_DIR\""
