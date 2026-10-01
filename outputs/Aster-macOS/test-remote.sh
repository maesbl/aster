#!/bin/zsh
set -eu
PROJECT_DIR="${0:A:h}"
TEST_DIR="${PROJECT_DIR:h:h}/work"
SOURCES=( "$PROJECT_DIR"/Shared/*.swift "$PROJECT_DIR"/Sources/*.swift )
SOURCES=( ${SOURCES:#*/App.swift} )
xcrun swiftc -D DEBUG -swift-version 5 -parse-as-library "${SOURCES[@]}" "$PROJECT_DIR/Tests/RemoteTests.swift" -o "$TEST_DIR/aster-remote-tests" -framework SwiftUI -framework AppKit -framework EventKit -framework UserNotifications -framework AVFoundation -framework ScreenCaptureKit -framework Security -framework ServiceManagement
"$TEST_DIR/aster-remote-tests" "$@"
