#!/bin/zsh
set -eu
PROJECT_DIR="${0:A:h}"
APP_DIR="${PROJECT_DIR:h}/Aster.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
xcrun swiftc -swift-version 5 -O -parse-as-library -target arm64-apple-macos14.0 "$PROJECT_DIR"/Sources/*.swift -o "$APP_DIR/Contents/MacOS/Aster" -framework AppKit -framework SwiftUI -framework EventKit -framework UserNotifications
cp "$PROJECT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/connection.json" "$APP_DIR/Contents/Resources/connection.json"
cp "$PROJECT_DIR/Assets/Aster.icns" "$APP_DIR/Contents/Resources/Aster.icns"
codesign --force --sign - "$APP_DIR"
echo "Aster.app compilada en $APP_DIR"
