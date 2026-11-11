#!/bin/bash
# Builds a Release Perch.app and packages dist/Perch.dmg + Perch.dmg.sha256,
# the two files install.sh and the in-app updater download.
#
# Usage: scripts/build-dmg.sh [extra make-a-dmg options, e.g. --no-window]
set -euo pipefail
cd "$(dirname "$0")/.."

MAKE_A_DMG_TAG=v1.0.1
BUILD=build/release
APP="$BUILD/Build/Products/Release/Perch.app"

rm -rf "$BUILD" dist
mkdir -p dist

echo "Building Release..."
xcodebuild -project Perch.xcodeproj -scheme Perch -configuration Release \
  -derivedDataPath "$BUILD" CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= -quiet build

# macOS keys Accessibility and Input Monitoring to the signature. A stable
# certificate keeps them granted across updates; ad-hoc changes every build.
if [ -n "${SIGN_IDENTITY:-}" ]; then
  codesign --force --sign "$SIGN_IDENTITY" ${SIGN_KEYCHAIN:+--keychain "$SIGN_KEYCHAIN"} "$APP"
  codesign --verify --strict "$APP"
  echo "Signed with $SIGN_IDENTITY"
else
  echo "warning: SIGN_IDENTITY not set, app is ad-hoc signed (permissions reset on every update)" >&2
fi

if command -v make-a-dmg >/dev/null 2>&1; then
  MAKE_A_DMG=make-a-dmg
else
  MAKE_A_DMG="$BUILD/make-a-dmg"
  curl -fsSL "https://raw.githubusercontent.com/azharbinanwar/make-a-dmg/$MAKE_A_DMG_TAG/make-a-dmg" -o "$MAKE_A_DMG"
  chmod +x "$MAKE_A_DMG"
fi

"$MAKE_A_DMG" "$APP" -y --no-open --sha256 -o dist/Perch.dmg "$@"
echo "Done: dist/Perch.dmg"
