#!/bin/zsh
set -eu
PROJECT_DIR="${0:A:h}"
TEST_DIR="${PROJECT_DIR:h:h}/work"
mkdir -p "$TEST_DIR"
xcrun swiftc -swift-version 5 -parse-as-library "$PROJECT_DIR/Sources/DesktopLayout.swift" "$PROJECT_DIR/Tests/DesktopTests.swift" -o "$TEST_DIR/aster-desktop-tests"
"$TEST_DIR/aster-desktop-tests"
xcrun swiftc -swift-version 5 -parse-as-library "$PROJECT_DIR/Sources/Avatar.swift" "$PROJECT_DIR/Sources/Models.swift" "$PROJECT_DIR/Sources/ComputerProtocol.swift" "$PROJECT_DIR/Sources/CoachProtocol.swift" "$PROJECT_DIR/Sources/Localization.swift" "$PROJECT_DIR/Tests/ProtocolTests.swift" -o "$TEST_DIR/aster-protocol-tests" -framework SwiftUI
"$TEST_DIR/aster-protocol-tests"
xcrun swiftc -swift-version 5 -parse-as-library "$PROJECT_DIR/Sources/Avatar.swift" "$PROJECT_DIR/Sources/Models.swift" "$PROJECT_DIR/Sources/ComputerProtocol.swift" "$PROJECT_DIR/Sources/CoachProtocol.swift" "$PROJECT_DIR/Sources/AgentAPI.swift" "$PROJECT_DIR/Sources/Localization.swift" "$PROJECT_DIR/Sources/RichMessage.swift" "$PROJECT_DIR/Sources/Store.swift" "$PROJECT_DIR/Sources/Routines.swift" "$PROJECT_DIR/Sources/MacServices.swift" "$PROJECT_DIR/Sources/Voice.swift" "$PROJECT_DIR/Sources/MacComputer.swift" "$PROJECT_DIR/Sources/ComputerController.swift" "$PROJECT_DIR/Sources/HealthServices.swift" "$PROJECT_DIR/Tests/WorkspaceTests.swift" -o "$TEST_DIR/aster-workspace-tests" -framework SwiftUI -framework AppKit -framework EventKit -framework UserNotifications -framework AVFoundation
"$TEST_DIR/aster-workspace-tests"
xcrun swiftc -swift-version 5 -parse-as-library "$PROJECT_DIR/Sources/Avatar.swift" "$PROJECT_DIR/Sources/Models.swift" "$PROJECT_DIR/Sources/ComputerProtocol.swift" "$PROJECT_DIR/Sources/CoachProtocol.swift" "$PROJECT_DIR/Sources/AgentAPI.swift" "$PROJECT_DIR/Sources/Localization.swift" "$PROJECT_DIR/Tests/APITests.swift" -o "$TEST_DIR/aster-api-tests" -framework SwiftUI
"$TEST_DIR/aster-api-tests"
COMMON_SOURCES=( "$PROJECT_DIR/Sources/Avatar.swift" "$PROJECT_DIR/Sources/Models.swift" "$PROJECT_DIR/Sources/ComputerProtocol.swift" "$PROJECT_DIR/Sources/CoachProtocol.swift" "$PROJECT_DIR/Sources/AgentAPI.swift" "$PROJECT_DIR/Sources/Localization.swift" "$PROJECT_DIR/Sources/RichMessage.swift" "$PROJECT_DIR/Sources/Store.swift" "$PROJECT_DIR/Sources/Routines.swift" "$PROJECT_DIR/Sources/MacServices.swift" "$PROJECT_DIR/Sources/Voice.swift" "$PROJECT_DIR/Sources/MacComputer.swift" "$PROJECT_DIR/Sources/ComputerController.swift" "$PROJECT_DIR/Sources/HealthServices.swift" )
xcrun swiftc -swift-version 5 -parse-as-library "${COMMON_SOURCES[@]}" "$PROJECT_DIR/Tests/ComputerTests.swift" -o "$TEST_DIR/aster-computer-tests" -framework SwiftUI -framework AppKit -framework EventKit -framework UserNotifications -framework AVFoundation -framework ScreenCaptureKit
"$TEST_DIR/aster-computer-tests"
xcrun swiftc -swift-version 5 -parse-as-library "${COMMON_SOURCES[@]}" "$PROJECT_DIR/Tests/ServicesTests.swift" -o "$TEST_DIR/aster-services-tests" -framework SwiftUI -framework AppKit -framework EventKit -framework UserNotifications -framework AVFoundation -framework ScreenCaptureKit
"$TEST_DIR/aster-services-tests"

xcrun swiftc -swift-version 5 -parse-as-library "${COMMON_SOURCES[@]}" "$PROJECT_DIR/Tests/DesktopChatTests.swift" -o "$TEST_DIR/aster-desktop-chat-tests" -framework SwiftUI -framework AppKit -framework EventKit -framework UserNotifications -framework AVFoundation -framework ScreenCaptureKit
"$TEST_DIR/aster-desktop-chat-tests"
xcrun swiftc -swift-version 5 -parse-as-library "${COMMON_SOURCES[@]}" "$PROJECT_DIR/Tests/CompanionTests.swift" -o "$TEST_DIR/aster-companion-tests" -framework SwiftUI -framework AppKit -framework EventKit -framework UserNotifications -framework AVFoundation -framework ScreenCaptureKit
"$TEST_DIR/aster-companion-tests"
