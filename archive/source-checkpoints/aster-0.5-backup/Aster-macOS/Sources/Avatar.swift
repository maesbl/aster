import SwiftUI
import AppKit

enum AvatarForm: String, Codable, CaseIterable { case pebble = "Pebble", pill = "Pill", orbit = "Orbit" }
enum AvatarMood: String, CaseIterable { case calm = "En calma", thinking = "Pensando", happy = "Contento", curious = "Curioso" }
enum AvatarTint: String, Codable, CaseIterable {
    case pearl = "Perla", lilac = "Lila", mint = "Menta", peach = "Melocotón", ink = "Tinta"
    var color: Color {
        switch self {
        case .pearl: return Color(red: 0.90, green: 0.90, blue: 0.88)
        case .lilac: return Color(red: 0.76, green: 0.73, blue: 0.96)
        case .mint: return Color(red: 0.67, green: 0.83, blue: 0.77)
        case .peach: return Color(red: 0.97, green: 0.76, blue: 0.64)
        case .ink: return Color(red: 0.22, green: 0.23, blue: 0.29)
        }
    }
    var eyes: Color { self == .ink ? .white : Color(red: 0.19, green: 0.19, blue: 0.25) }
}

struct AvatarStyle: Codable, Equatable {
    var form: AvatarForm = .pebble
    var tint: AvatarTint = .lilac
    var size: Double = 140
    var effects: Bool = true
    var motion: Bool = true
}

private struct GazeMotion {
    var start = CGPoint.zero
    var target = CGPoint.zero
    var changed: Double = 0
    func position(at time: Double) -> CGPoint {
        let blend = 1 - exp(-max(0, time - changed) * 16)
        return CGPoint(x: start.x + (target.x - start.x) * blend, y: start.y + (target.y - start.y) * blend)
    }
    mutating func move(to point: CGPoint) {
        let now = Date().timeIntervalSinceReferenceDate
        start = position(at: now); target = point; changed = now
    }
}

struct CompanionAvatar: View {
    var style: AvatarStyle
    var mood: AvatarMood = .calm
    var dimension: CGFloat = 150
    var animateAtRest = true
    var framesPerSecond: Double = 60
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var gaze = GazeMotion()
    @State private var visible = false
    @State private var hovering = false
    @State private var previousMood = AvatarMood.calm
    @State private var moodChanged: Double = 0
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / framesPerSecond, paused: reduceMotion || !style.motion || !visible || (!animateAtRest && !hovering))) { timeline in
            let time = reduceMotion || !style.motion || (!animateAtRest && !hovering) ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let seed = Double(AvatarTint.allCases.firstIndex(of: style.tint) ?? 0) * 0.71
            let look = time == 0 ? CGPoint.zero : gaze.position(at: time)
            let moodProgress = time == 0 || moodChanged == 0 ? 1 : min(1, max(0, (time - moodChanged) / 0.24))
            let blend = moodProgress * moodProgress * (3 - 2 * moodProgress)
            let happy = (previousMood == .happy ? 1.0 : 0) * (1 - blend) + (mood == .happy ? 1.0 : 0) * blend
            let curious = (previousMood == .curious ? 1.0 : 0) * (1 - blend) + (mood == .curious ? 1.0 : 0) * blend
            let thinking = (previousMood == .thinking ? 1.0 : 0) * (1 - blend) + (mood == .thinking ? 1.0 : 0) * blend
            Canvas(rendersAsynchronously: true) { context, size in
                let unit = min(size.width, size.height)
                let breathe = time == 0 ? 0 : sin(time * 1.65 + seed) * 0.014
                let bob = time == 0 ? 0 : sin(time * 1.3 + seed) * unit * 0.018
                let center = CGPoint(x: size.width / 2, y: size.height / 2 + bob)
                let baseWidth = unit * (style.form == .pill ? 0.76 : 0.65)
                let baseHeight = unit * (style.form == .pill ? 0.51 : style.form == .orbit ? 0.65 : 0.69)
                let width = baseWidth * (1 + breathe), height = baseHeight * (1 - breathe)
                let rect = CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
                let shadow = CGRect(x: center.x - baseWidth * 0.38, y: center.y + baseHeight * 0.55,
                                    width: baseWidth * 0.76, height: unit * 0.025)
                context.fill(Path(ellipseIn: shadow), with: .color(.black.opacity(0.055)))
                if style.effects {
                    for i in 0..<3 {
                        let angle = time * 0.24 + Double(i) * 2.095
                        let point = CGPoint(x: center.x + cos(angle) * unit * 0.44, y: center.y + sin(angle) * unit * 0.38)
                        context.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: 3, height: 3)), with: .color(style.tint.color.opacity(0.6)))
                    }
                }
                let shape: Path = style.form == .orbit ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: baseWidth * (style.form == .pill ? 0.45 : 0.36))
                context.fill(shape, with: .linearGradient(Gradient(colors: [style.tint.color.opacity(0.8), style.tint.color]),
                    startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
                context.stroke(shape, with: .color(.white.opacity(style.tint == .ink ? 0.09 : 0.45)), lineWidth: 1)
                if style.form == .orbit && style.effects {
                    var arc = Path()
                    arc.addArc(center: center, radius: baseWidth * 0.61, startAngle: .degrees(time * 18), endAngle: .degrees(time * 18 + 200), clockwise: false)
                    context.stroke(arc, with: .color(style.tint.color.opacity(0.4)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }
                let blinkPhase = (time + seed).truncatingRemainder(dividingBy: 5.3)
                let blink = time == 0 ? 0 : max(0, 1 - abs(blinkPhase - 5.15) / 0.10)
                let lookX = look.x * unit * 0.035 + (time == 0 ? 0 : sin(time * 0.44 + seed) * unit * 0.012)
                let eyeWidth = unit * 0.039
                let eyeHeight = unit * (0.073 + curious * 0.012) * (1 - blink * 0.85)
                for side in [-1.0, 1.0] {
                    let eyeX = center.x + CGFloat(side) * unit * 0.095 + lookX
                    let eyeY = center.y - unit * 0.025 + look.y * unit * 0.025
                    let smileAmount = happy * (1 - blink)
                    if smileAmount > 0 {
                        var smile = Path()
                        smile.move(to: CGPoint(x: eyeX - eyeWidth, y: eyeY + eyeWidth / 2))
                        smile.addQuadCurve(to: CGPoint(x: eyeX + eyeWidth, y: eyeY + eyeWidth / 2), control: CGPoint(x: eyeX, y: eyeY - eyeWidth))
                        context.stroke(smile, with: .color(style.tint.eyes.opacity(smileAmount)), style: StrokeStyle(lineWidth: unit * 0.022, lineCap: .round))
                    }
                    if smileAmount < 1 {
                        let eye = CGRect(x: eyeX - eyeWidth / 2, y: eyeY - eyeHeight / 2, width: eyeWidth, height: eyeHeight)
                        context.fill(Path(roundedRect: eye, cornerRadius: eyeWidth / 2), with: .color(style.tint.eyes.opacity(1 - smileAmount)))
                    }
                }
                if thinking > 0 {
                    for i in 0..<3 {
                        let x = center.x + CGFloat(i - 1) * unit * 0.055
                        let alpha = time == 0 ? 0.6 : 0.3 + 0.55 * (0.5 + 0.5 * sin(time * 3 - Double(i)))
                        context.fill(Path(ellipseIn: CGRect(x: x, y: center.y + unit * 0.17, width: unit * 0.018, height: unit * 0.018)), with: .color(style.tint.eyes.opacity(alpha * thinking)))
                    }
                }
            }
        }
        .frame(width: dimension, height: dimension)
        .onContinuousHover { phase in
            switch phase {
            case .active(let location): hovering = true; gaze.move(to: CGPoint(x: (location.x / dimension - 0.5) * 2, y: (location.y / dimension - 0.5) * 2))
            case .ended: hovering = false; gaze.move(to: .zero)
            }
        }
        .onAppear { visible = true; previousMood = mood }
        .onDisappear { visible = false }
        .background(WindowAnimationVisibility { visible = $0 })
        .onChange(of: mood) { old, _ in previousMood = old; moodChanged = Date().timeIntervalSinceReferenceDate }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Compañero \(style.form.rawValue), color \(style.tint.rawValue), \(mood.rawValue)")
    }
}

private struct WindowAnimationVisibility: NSViewRepresentable {
    var changed: (Bool) -> Void
    func makeNSView(context: Context) -> VisibilityView { let view = VisibilityView(); view.changed = changed; return view }
    func updateNSView(_ view: VisibilityView, context: Context) { view.changed = changed }
    final class VisibilityView: NSView {
        var changed: ((Bool) -> Void)?
        private var observer: NSObjectProtocol?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow(); if let observer { NotificationCenter.default.removeObserver(observer) }; observer = nil
            guard let window else { changed?(false); return }
            observer = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main) { [weak self, weak window] _ in self?.changed?(window?.occlusionState.contains(.visible) == true) }
            DispatchQueue.main.async { [weak self, weak window] in self?.changed?(window?.occlusionState.contains(.visible) == true) }
        }
        deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    }
}
