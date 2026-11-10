#!/bin/zsh
# Универсальная сборка BatteryLens (Apple Silicon + Intel).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(cat VERSION)"
APP="BatteryLens.app"
BUNDLE_ID="io.github.batterylens.app"
MIN_MACOS="13.0"

rm -rf "$APP" build
mkdir -p build "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "→ Сборка BatteryLens $VERSION (arm64 + x86_64)…"

BINARIES=()
for ARCH in arm64 x86_64; do
  OUT="build/BatteryLens-$ARCH"
  swiftc -O \
    -target "${ARCH}-apple-macos${MIN_MACOS}" \
    -o "$OUT" \
    Sources/main.swift \
    -framework Cocoa -framework IOKit
  BINARIES+=("$OUT")
done

lipo -create "${BINARIES[@]}" -output "$APP/Contents/MacOS/BatteryLens"
chmod +x "$APP/Contents/MacOS/BatteryLens"

cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP/Contents/Info.plist"

# Ad-hoc подпись: приложение не требует аккаунта разработчика,
# но macОS спокойнее запускает подписанный бандл.
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "✓ Готово: $APP"
lipo -archs "$APP/Contents/MacOS/BatteryLens" | sed 's/^/  архитектуры: /'
echo
echo "  Проверка:  ./$APP/Contents/MacOS/BatteryLens --print"
echo "  Запуск:    open $APP"
