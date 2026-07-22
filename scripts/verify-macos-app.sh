#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="${1:-$ROOT_DIR/dist/Super Mario 63.app}"
LAUNCHER="$APP_DIR/Contents/MacOS/SuperMario63"
RUNTIME="$APP_DIR/Contents/Resources/RuffleRuntime"
MOVIE="$APP_DIR/Contents/Resources/Super Mario 63.swf"

for required_file in \
    "$APP_DIR/Contents/Info.plist" \
    "$LAUNCHER" \
    "$RUNTIME" \
    "$MOVIE" \
    "$APP_DIR/Contents/Resources/AppIcon.icns" \
    "$APP_DIR/Contents/Resources/RUFFLE_LICENSE.md"
do
    if [[ ! -f "$required_file" ]]; then
        echo "error: missing app component: $required_file" >&2
        exit 1
    fi
done

assert_arm64_only() {
    local executable="$1"
    local architectures
    architectures="$(lipo -archs "$executable")"
    if [[ "$architectures" != "arm64" ]]; then
        echo "error: expected arm64-only executable, got '$architectures': $executable" >&2
        exit 1
    fi
}

assert_arm64_only "$LAUNCHER"
assert_arm64_only "$RUNTIME"

plutil -lint "$APP_DIR/Contents/Info.plist" >/dev/null
codesign --verify --deep --strict "$APP_DIR"
cmp --silent "$ROOT_DIR/Publish/Super_Mario_63_2010.swf" "$MOVIE"

RUNTIME_VERSION="$("$LAUNCHER" --runtime-version)"
if [[ "$RUNTIME_VERSION" != Ruffle* ]]; then
    echo "error: bundled runtime did not report a Ruffle version" >&2
    exit 1
fi

echo "Verified: arm64 launcher, arm64 Metal runtime, signature, resources"
echo "Runtime: $RUNTIME_VERSION"
