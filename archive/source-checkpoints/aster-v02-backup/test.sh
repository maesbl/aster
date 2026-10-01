#!/bin/zsh
set -eu
PROJECT_DIR="${0:A:h}"
TEST_BINARY="${PROJECT_DIR:h:h}/work/aster-protocol-tests"
xcrun swiftc -swift-version 5 -parse-as-library "$PROJECT_DIR/Sources/Avatar.swift" "$PROJECT_DIR/Sources/Models.swift" "$PROJECT_DIR/Tests/ProtocolTests.swift" -o "$TEST_BINARY" -framework SwiftUI
"$TEST_BINARY"
