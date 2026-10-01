import Foundation
import CoreGraphics

@main struct DesktopTests {
    static func main() {
        let primary = CGRect(x: 0, y: 25, width: 1470, height: 898)
        let external = CGRect(x: -1920, y: 120, width: 1920, height: 1080)
        let small = CGRect(x: 300, y: -480, width: 640, height: 440)
        for screen in [primary, external, small] {
            let frames = DesktopLayout.column(count: 6, screen: screen)
            precondition(frames.count == 6 && frames.allSatisfy { screen.contains($0) })
            precondition(frames.allSatisfy { $0.width <= 94 && $0.height <= 96 })
            for index in 1..<frames.count {
                precondition(frames[index - 1].minY > frames[index].maxY, "Companions overlap")
                precondition(frames[index].maxX == frames[0].maxX, "Column is not aligned")
            }
            precondition(screen.maxY - frames[0].maxY == 12 && screen.maxX - frames[0].maxX == 12)
        }
        for screen in [primary, external, small] {
            let frames = DesktopLayout.column(count: 6, screen: screen, topInset: 44)
            precondition(frames.allSatisfy { screen.contains($0) })
            precondition(screen.maxY - frames[0].maxY == 56, "Header must not overlap the first companion")
            for anchor in frames + [CGRect(x: screen.minX + 12, y: screen.minY + 12, width: 94, height: 96)] {
                let chat = DesktopLayout.chatFrame(anchor: anchor, screen: screen)
                precondition(screen.contains(chat), "Mini chat must fit on its monitor")
                precondition(!chat.intersects(anchor), "Mini chat must not cover its companion when space is available")
            }
        }
        let moved = CGRect(x: -1600, y: 300, width: 94, height: 96)
        precondition(DesktopLayout.clamped(moved, screens: [primary, external]) == moved, "An intentional position was changed")
        let recovered = DesktopLayout.clamped(moved, screens: [primary])
        precondition(primary.contains(recovered), "A companion was lost when a monitor disconnected")
        let partlyOutside = CGRect(x: 1450, y: -20, width: 94, height: 96)
        precondition(primary.contains(DesktopLayout.clamped(partlyOutside, screens: [primary, external])))
        precondition(DesktopLayout.column(count: 0, screen: primary).isEmpty)
        print("Desktop: six compact companions fit without overlap, negative monitor coordinates work, moved positions survive, disconnected screens recover.")
    }
}
