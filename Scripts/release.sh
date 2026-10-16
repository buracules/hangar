#!/bin/bash
# Builds a signed, notarized DMG of the release app into dist/.
#
#   Scripts/release.sh                                    # Developer ID + notarization
#   SKIP_NOTARIZE=1 SIGN_IDENTITY=- Scripts/release.sh    # local dry run, ad-hoc signed
#
# One-time setup: a "Developer ID Application" certificate in the keychain, and a notary
# profile. Hangar shares Margin's (same team):
#   xcrun notarytool store-credentials margin-notary --apple-id <id> --team-id Z29XX544J8
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(sed -nE 's/.*MARKETING_VERSION: "?([0-9.]+)"?.*/\1/p' project.yml | head -1)
IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
PROFILE="${NOTARY_PROFILE:-margin-notary}"
APP=build/Build/Products/Release/Hangar.app
DMGBUILD=build/.venv-dmg/bin/dmgbuild
DMGBUILD_VERSION=1.6.5
DMG="dist/Hangar-$VERSION.dmg"

echo "==> Building Hangar $VERSION (Release)"
xcodegen -q
xcodebuild -project Hangar.xcodeproj -scheme Hangar -configuration Release \
  -derivedDataPath build build -quiet CODE_SIGN_IDENTITY=-

echo "==> Signing with $IDENTITY"
# Hardened runtime, as notarization requires; the entitlements keep Apple Events to UTM.
codesign --force --options runtime --timestamp --sign "$IDENTITY" \
  --entitlements Sources/Hangar.entitlements "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> Creating $DMG"
# dmgbuild lays out the installer window (background, icon size and positions) without
# driving Finder; it lives in a venv under build/.
if [[ ! -x "$DMGBUILD" ]]; then
  python3 -m venv build/.venv-dmg
  build/.venv-dmg/bin/pip install --quiet "dmgbuild==$DMGBUILD_VERSION"
fi
mkdir -p dist
rm -f "$DMG"
"$DMGBUILD" -s Scripts/dmg/settings.py -D app="$APP" -D art=Scripts/dmg \
  "Hangar $VERSION" "$DMG" >/dev/null
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

if [[ "${SKIP_NOTARIZE:-0}" == "1" ]]; then
  echo "==> Skipping notarization"
else
  echo "==> Notarizing (this takes a few minutes)"
  xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$DMG"
  spctl --assess --type open --context context:primary-signature --verbose "$DMG"
fi

echo "==> $DMG ($(du -h "$DMG" | cut -f1))"
