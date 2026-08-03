#!/bin/sh
# Perch installer — downloads the latest release, verifies it, installs to /Applications.
# Usage: curl -fsSL perch.kodeelite.com/install.sh | sh
set -eu

URL="https://github.com/azharbinanwar/perch-releases/releases/latest/download/Perch.dmg"
TMP="$(mktemp -d)"
MNT=""
cleanup() {
  [ -n "$MNT" ] && hdiutil detach "$MNT" -quiet 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT

echo "Downloading Perch…"
curl -fL --progress-bar "$URL" -o "$TMP/Perch.dmg"

if curl -fsL "$URL.sha256" -o "$TMP/Perch.dmg.sha256" 2>/dev/null; then
  want="$(awk '{print $1}' "$TMP/Perch.dmg.sha256")"
  got="$(shasum -a 256 "$TMP/Perch.dmg" | awk '{print $1}')"
  if [ "$want" != "$got" ]; then
    echo "Checksum mismatch — download may be corrupted. Aborting." >&2
    exit 1
  fi
  echo "Checksum verified."
fi

MNT="$(hdiutil attach "$TMP/Perch.dmg" -nobrowse -readonly | awk -F'\t' '/\/Volumes\//{print $NF; exit}')"
echo "Installing to /Applications…"
rm -rf /Applications/Perch.app
ditto "$MNT/Perch.app" /Applications/Perch.app
hdiutil detach "$MNT" -quiet
MNT=""

# Clear Gatekeeper quarantine so first launch doesn't need right-click → Open.
xattr -dr com.apple.quarantine /Applications/Perch.app 2>/dev/null || true

echo "✓ Perch installed."
open /Applications/Perch.app
