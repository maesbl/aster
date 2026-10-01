#!/bin/zsh
set -eu
PROJECT_DIR="$PWD/outputs/Aster-macOS"
COMMON_SOURCES=( "$PROJECT_DIR/Sources/Avatar.swift" "$PROJECT_DIR/Sources/Models.swift" "$PROJECT_DIR/Sources/ComputerProtocol.swift" "$PROJECT_DIR/Sources/CoachProtocol.swift" "$PROJECT_DIR/Sources/AgentAPI.swift" "$PROJECT_DIR/Sources/Localization.swift" "$PROJECT_DIR/Sources/RichMessage.swift" "$PROJECT_DIR/Sources/Store.swift" "$PROJECT_DIR/Sources/Routines.swift" "$PROJECT_DIR/Sources/MacServices.swift" "$PROJECT_DIR/Sources/Voice.swift" "$PROJECT_DIR/Sources/MacComputer.swift" "$PROJECT_DIR/Sources/ComputerController.swift" "$PROJECT_DIR/Sources/HealthServices.swift" )
xcrun swiftc -swift-version 5 -parse-as-library "${COMMON_SOURCES[@]}" work/LiveCompanionCheck.swift -o work/aster-live-companion-check -framework SwiftUI -framework AppKit -framework EventKit -framework UserNotifications -framework AVFoundation -framework ScreenCaptureKit
work/aster-live-companion-check
