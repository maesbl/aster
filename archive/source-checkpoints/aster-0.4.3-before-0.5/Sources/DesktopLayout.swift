import Foundation
import CoreGraphics

enum DesktopLayout {
    static let margin: CGFloat = 12
    static let gap: CGFloat = 4
    static func panelSize(count: Int, screen: CGRect, topInset: CGFloat = 0) -> CGSize {
        let available = max(1, screen.height - margin * 2 - topInset - CGFloat(max(0, count - 1)) * gap)
        return CGSize(width: min(94, screen.width), height: min(96, available / CGFloat(max(1, count))))
    }
    static func column(count: Int, screen: CGRect, topInset: CGFloat = 0) -> [CGRect] {
        let size = panelSize(count: count, screen: screen, topInset: topInset)
        return (0..<max(0, count)).map { index in
            CGRect(x: screen.maxX - size.width - margin,
                   y: screen.maxY - margin - topInset - size.height - CGFloat(index) * (size.height + gap),
                   width: size.width, height: size.height)
        }
    }
    static func chatFrame(anchor: CGRect, screen: CGRect, size: CGSize = CGSize(width: 320, height: 390)) -> CGRect {
        let width = min(size.width, max(1, screen.width - margin * 2))
        let height = min(size.height, max(1, screen.height - margin * 2))
        let left = anchor.minX - 8 - width
        let right = anchor.maxX + 8
        let x = left >= screen.minX + margin ? left : right + width <= screen.maxX - margin ? right : screen.maxX - width - margin
        let y = min(max(anchor.maxY - height, screen.minY + margin), screen.maxY - height - margin)
        return clamped(CGRect(x: x, y: y, width: width, height: height), screens: [screen])
    }
    static func clamped(_ frame: CGRect, screens: [CGRect]) -> CGRect {
        guard frame.origin.x.isFinite, frame.origin.y.isFinite, !screens.isEmpty else { return frame }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let screen = screens.max { lhs, rhs in
            func score(_ candidate: CGRect) -> CGFloat {
                let overlap = frame.intersection(candidate)
                if !overlap.isNull, overlap.width * overlap.height > 0 { return overlap.width * overlap.height }
                return -hypot(center.x - candidate.midX, center.y - candidate.midY)
            }
            return score(lhs) < score(rhs)
        }!
        var result = frame
        result.size.width = min(frame.width, screen.width)
        result.size.height = min(frame.height, screen.height)
        result.origin.x = min(max(frame.minX, screen.minX), screen.maxX - result.width)
        result.origin.y = min(max(frame.minY, screen.minY), screen.maxY - result.height)
        return result
    }
}
