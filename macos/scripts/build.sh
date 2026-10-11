#!/usr/bin/env bash
# Builds USBeep.app out of the SwiftPM release binary.
#
#   macos/scripts/build.sh              build the binary and assemble the bundle
#   macos/scripts/build.sh --skip-build reuse the binary already in .build
#
# UNUserNotificationCenter and SMAppService only work for a real bundle with a
# bundle identifier, so the bare binary from `swift build` is not runnable on
# its own — always go through this script.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$MACOS_DIR/.." && pwd)"
APP_NAME="USBeep"
BUILD_DIR="$MACOS_DIR/.build"
APP_BUNDLE="$MACOS_DIR/$APP_NAME.app"
PLIST_BUDDY="/usr/libexec/PlistBuddy"
SKIP_BUILD=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-build) SKIP_BUILD=1 ;;
        *) echo "Error: unknown option '$1'" >&2; exit 1 ;;
    esac
    shift
done

cd "$MACOS_DIR"

if [[ "$SKIP_BUILD" -eq 0 ]]; then
    echo "==> Building release binary..."
    swift build -c release
fi

BINARY="$BUILD_DIR/release/$APP_NAME"
if [[ ! -f "$BINARY" ]]; then
    echo "Error: binary not found at $BINARY" >&2
    exit 1
fi

echo "==> Assembling $APP_NAME.app..."
# Replacing the bundle under a running copy leaves that process alive with a
# deleted executable. Only the instance launched from *this* bundle is
# stopped — a copy in /Applications is left alone.
if pgrep -f "^$APP_BUNDLE/Contents/MacOS/$APP_NAME$" >/dev/null 2>&1; then
    echo "    stopping the running instance of this bundle"
    pkill -f "^$APP_BUNDLE/Contents/MacOS/$APP_NAME$" || true
    sleep 0.5
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$MACOS_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

APP_BUILD="$(git -C "$REPO_DIR" rev-list --count HEAD 2>/dev/null || echo 1)"
"$PLIST_BUDDY" -c "Set :CFBundleVersion $APP_BUILD" "$APP_BUNDLE/Contents/Info.plist"
# The release workflow passes the version from the git tag (v0.2.0 → 0.2.0).
if [[ -n "${APP_VERSION:-}" ]]; then
    "$PLIST_BUDDY" -c "Set :CFBundleShortVersionString $APP_VERSION" "$APP_BUNDLE/Contents/Info.plist"
fi

# Finder metadata makes codesign fail with "resource fork, Finder information,
# or similar detritus not allowed".
xattr -cr "$APP_BUNDLE"

echo "==> Codesigning (ad-hoc)..."
codesign --force --sign - "$APP_BUNDLE"
codesign -v "$APP_BUNDLE"

echo "==> Built $APP_BUNDLE"
