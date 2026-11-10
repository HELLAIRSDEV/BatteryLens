#!/bin/zsh
# Упаковка релиза: .zip и .dmg в dist/
set -euo pipefail
cd "$(dirname "$0")/.."

APP="BatteryLens.app"
VERSION="$(cat VERSION)"
DIST="dist"

[ -d "$APP" ] || { echo "Сначала запусти scripts/build.sh"; exit 1; }

rm -rf "$DIST"
mkdir -p "$DIST"

echo "→ ZIP…"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST/BatteryLens-$VERSION.zip"

echo "→ DMG…"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "BatteryLens $VERSION" \
  -srcfolder "$STAGE" -ov -format UDZO \
  "$DIST/BatteryLens-$VERSION.dmg"
rm -rf "$STAGE"

shasum -a 256 "$DIST"/* | sed 's|dist/||'

echo "✓ Релиз в $DIST/"
