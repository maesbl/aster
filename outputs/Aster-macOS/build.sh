#!/bin/zsh
set -eu
PROJECT_DIR="${0:A:h}"
APP_DIR="${ASTER_APP_DIR:-${PROJECT_DIR:h}/Aster.app}"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "${PROJECT_DIR:h:h}/work"
ICON_WORK="$(mktemp -d "${PROJECT_DIR:h:h}/work/aster-icon.XXXXXX")"
trap 'rm -rf "$ICON_WORK"' EXIT
xcrun swift "$PROJECT_DIR/Assets/Icon.swift" "$ICON_WORK/Aster.iconset"
/usr/bin/iconutil -c icns "$ICON_WORK/Aster.iconset" -o "$PROJECT_DIR/Assets/Aster.icns"
cp "$ICON_WORK/Aster.iconset/icon_512x512@2x.png" "$PROJECT_DIR/Assets/Aster.png"
ARCHITECTURES=(${=ASTER_ARCHS:-arm64})
BINARIES=()
for ARCHITECTURE in "${ARCHITECTURES[@]}"; do
  BINARY="$ICON_WORK/Aster-$ARCHITECTURE"
  xcrun swiftc -swift-version 5 -O -parse-as-library -target "$ARCHITECTURE-apple-macos14.0" "$PROJECT_DIR"/Shared/*.swift "$PROJECT_DIR"/Sources/*.swift -o "$BINARY" -framework AppKit -framework SwiftUI -framework EventKit -framework UserNotifications -framework AVFoundation -framework ScreenCaptureKit -framework ApplicationServices -framework Security -framework ServiceManagement
  BINARIES+=("$BINARY")
done
xcrun lipo -create "${BINARIES[@]}" -output "$APP_DIR/Contents/MacOS/Aster"
cp "$PROJECT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
rm -f "$APP_DIR/Contents/Resources/connection.json"
cp -R "$PROJECT_DIR/Localization" "$APP_DIR/Contents/Resources/"
cp "$PROJECT_DIR/Assets/Aster.icns" "$APP_DIR/Contents/Resources/Aster.icns"
if [[ -n "${ASTER_DEVELOPER_ID:-}" ]]; then
  codesign --force --options runtime --timestamp --entitlements "$PROJECT_DIR/Release.entitlements" --sign "$ASTER_DEVELOPER_ID" "$APP_DIR"
  codesign --verify --strict "$APP_DIR"
else
  /usr/bin/python3 "$PROJECT_DIR/sign-local.py" "$APP_DIR"
fi
echo "Aster.app compilada en $APP_DIR"
