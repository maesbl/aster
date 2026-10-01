import SwiftUI
import AppKit

enum AsterAppearance: String, CaseIterable {
    case system = "Sistema", light = "Claro", dark = "Oscuro"
    var scheme: ColorScheme? { self == .system ? nil : self == .dark ? .dark : .light }
    var symbol: String { self == .system ? "circle.lefthalf.filled" : self == .light ? "sun.max" : "moon" }
}

enum AsterMotion {
    static func spring(_ reduced: Bool) -> Animation? { reduced ? nil : .spring(duration: 0.48, bounce: 0.12) }
    static func quick(_ reduced: Bool) -> Animation? { reduced ? nil : .smooth(duration: 0.22) }
}

struct WindowVibrancy: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground; view.blendingMode = .behindWindow; view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

struct AmbientBackdrop: View {
    var tint: Color
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if !reduceTransparency { WindowVibrancy() }
                (scheme == .dark ? Color(red: 0.095, green: 0.10, blue: 0.14) : Color(red: 0.94, green: 0.95, blue: 0.98)).opacity(reduceTransparency ? 1 : 0.9)
                if !reduceTransparency {
                    TimelineView(.animation(minimumInterval: 1.0 / 24, paused: reduceMotion)) { clock in
                        let time = reduceMotion ? 0 : clock.date.timeIntervalSinceReferenceDate
                        Canvas(rendersAsynchronously: true) { context, size in
                            let colors = [tint, Color(red: 0.43, green: 0.64, blue: 0.91), Color(red: 0.92, green: 0.63, blue: 0.75)]
                            let positions: [(Double, Double)] = [(0.73, 0.18), (0.30, 0.84), (1.06, 0.78)]
                            for index in 0..<3 {
                                let x = positions[index].0 + sin(time * 0.09 + Double(index) * 2) * 0.08
                                let y = positions[index].1 + cos(time * 0.07 + Double(index)) * 0.06
                                let center = CGPoint(x: size.width * x, y: size.height * y)
                                let radius = max(size.width, size.height) * 0.60
                                let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                                context.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [colors[index].opacity(scheme == .dark ? 0.19 : 0.20), .clear]), center: center, startRadius: 0, endRadius: radius))
                            }
                        }
                    }
                }
            }.frame(width: proxy.size.width, height: proxy.size.height).clipped()
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}

private struct LiquidSurface: ViewModifier {
    var radius: CGFloat
    var tint: Color?
    var interactive: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
        } else if #available(macOS 26.0, *) {
            content.glassEffect(.regular.tint(tint).interactive(interactive), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.24 : 0.8), .white.opacity(0.06), .white.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
        }
    }
}

private struct FrostedSurface: ViewModifier {
    var radius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content
            .background {
                if reduceTransparency { RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color(nsColor: .windowBackgroundColor)) }
                else { RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.regularMaterial) }
            }
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.18 : 0.82), .white.opacity(0.10), .white.opacity(scheme == .dark ? 0.10 : 0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            .shadow(color: .black.opacity(scheme == .dark ? 0.12 : 0.025), radius: 18, y: 8)
    }
}

extension View {
    func liquidSurface(_ radius: CGFloat = 20, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(LiquidSurface(radius: radius, tint: tint, interactive: interactive))
    }
    func frostedSurface(_ radius: CGFloat = 22) -> some View { modifier(FrostedSurface(radius: radius)) }
    @ViewBuilder func liquidID(_ id: String, in namespace: Namespace.ID) -> some View {
        if #available(macOS 26.0, *) { self.glassEffectID(id, in: namespace) } else { self }
    }
    @ViewBuilder func glassControl(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent { buttonStyle(.glassProminent) } else { buttonStyle(.glass) }
        } else {
            if prominent { buttonStyle(.borderedProminent) } else { buttonStyle(.bordered) }
        }
    }
}

struct LiquidGroup<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: () -> Content
    @ViewBuilder var body: some View {
        if #available(macOS 26.0, *) { GlassEffectContainer(spacing: spacing, content: content) }
        else { content() }
    }
}

struct FluidButtonStyle: ButtonStyle {
    var lift: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        FluidButtonBody(configuration: configuration, lift: lift, reduced: reduceMotion, enabled: enabled)
    }
    private struct FluidButtonBody: View {
        let configuration: ButtonStyle.Configuration
        let lift: CGFloat
        let reduced: Bool
        let enabled: Bool
        @State private var hovering = false
        var body: some View {
            configuration.label
                .scaleEffect(reduced ? 1 : configuration.isPressed ? 0.965 : hovering && lift > 0 ? 1.018 : 1)
                .offset(y: reduced || configuration.isPressed ? 0 : hovering ? -lift : 0)
                .opacity(enabled ? 1 : 0.42)
                .animation(AsterMotion.quick(reduced), value: hovering)
                .animation(AsterMotion.quick(reduced), value: configuration.isPressed)
                .onHover { hovering = $0 }
        }
    }
}

struct GlassAction: View {
    var title: String
    var symbol: String
    var prominent = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 16).padding(.vertical, 11)
                .liquidSurface(22, tint: prominent ? Color.accentColor.opacity(0.18) : nil, interactive: true)
        }.buttonStyle(FluidButtonStyle(lift: 1))
    }
}

struct GlassIconButton: View {
    var symbol: String
    var title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13, weight: .medium)).frame(width: 36, height: 36).liquidSurface(18, interactive: true)
        }.buttonStyle(FluidButtonStyle()).accessibilityLabel(title).help(title)
    }
}

struct MoodPicker: View {
    @Binding var selection: AvatarMood
    var tint: Color
    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        LiquidGroup(spacing: 4) {
            HStack(spacing: 3) {
                ForEach(AvatarMood.allCases, id: \.self) { mood in
                    Button { withAnimation(AsterMotion.spring(reduceMotion)) { selection = mood } } label: {
                        Text(mood.rawValue).font(.system(size: 10, weight: selection == mood ? .semibold : .regular)).padding(.horizontal, 12).padding(.vertical, 9)
                            .background {
                                if selection == mood { Capsule().fill(tint.opacity(0.12)).matchedGeometryEffect(id: "mood", in: namespace) }
                            }
                    }.buttonStyle(FluidButtonStyle()).accessibilityAddTraits(selection == mood ? .isSelected : [])
                }
            }.padding(4).liquidSurface(24)
        }
    }
}

struct AvatarStage: View {
    var style: AvatarStyle
    var mood: AvatarMood
    var dimension: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            if style.effects && !reduceTransparency {
                Ellipse().fill(RadialGradient(colors: [style.tint.color.opacity(0.24), .clear], center: .center, startRadius: 0, endRadius: dimension * 0.52)).frame(width: dimension * 1.25, height: dimension)
                    .offset(y: 16)
                Ellipse().strokeBorder(LinearGradient(colors: [.white.opacity(0.8), style.tint.color.opacity(0.35), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    .frame(width: dimension * 0.76, height: dimension * 0.16).offset(y: dimension * 0.40)
            }
            CompanionAvatar(style: style, mood: mood, dimension: dimension)
        }.frame(width: dimension * 1.3, height: dimension)
    }
}
