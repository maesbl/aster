#!/bin/zsh
set -eu
PROJECT_DIR="${0:A:h}"
APP_DIR="${PROJECT_DIR:h}/Aster.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "${PROJECT_DIR:h:h}/work"
ICON_WORK="$(mktemp -d "${PROJECT_DIR:h:h}/work/aster-icon.XXXXXX")"
trap 'rm -rf "$ICON_WORK"' EXIT
xcrun swift "$PROJECT_DIR/Assets/Icon.swift" "$ICON_WORK/Aster.iconset"
/usr/bin/iconutil -c icns "$ICON_WORK/Aster.iconset" -o "$PROJECT_DIR/Assets/Aster.icns"
cp "$ICON_WORK/Aster.iconset/icon_512x512@2x.png" "$PROJECT_DIR/Assets/Aster.png"
xcrun swiftc -swift-version 5 -O -parse-as-library -target arm64-apple-macos14.0 "$PROJECT_DIR"/Sources/*.swift -o "$APP_DIR/Contents/MacOS/Aster" -framework AppKit -framework SwiftUI -framework EventKit -framework UserNotifications -framework AVFoundation -framework ScreenCaptureKit -framework ApplicationServices
cp "$PROJECT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/connection.json" "$APP_DIR/Contents/Resources/connection.json"
cp -R "$PROJECT_DIR/Localization" "$APP_DIR/Contents/Resources/"
cp "$PROJECT_DIR/Assets/Aster.icns" "$APP_DIR/Contents/Resources/Aster.icns"
/usr/bin/python3 "$PROJECT_DIR/sign-local.py" "$APP_DIR"
echo "Aster.app compilada en $APP_DIR"
