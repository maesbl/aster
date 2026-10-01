from pathlib import Path
p=Path('outputs/Aster-macOS/Sources/Design.swift');s=p.read_text()
a=s.index('struct AmbientBackdrop: View {');b=s.index('\nprivate struct LiquidSurface:',a)
s=s[:a]+'''struct AmbientBackdrop: View {
    var tint: Color
    @Environment(\\.colorScheme) private var scheme
    var body: some View {
        LinearGradient(colors: scheme == .dark ? [Color(white: 0.065), Color(white: 0.095)] : [Color(white: 0.975), Color(white: 0.94)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}
''' +s[b:]
a=s.index('private struct FrostedSurface: ViewModifier {');b=s.index('\nextension View',a)
s=s[:a]+'''private struct FrostedSurface: ViewModifier {
    var radius: CGFloat
    @Environment(\\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.background(scheme == .dark ? Color(white: 0.115) : .white, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(.primary.opacity(scheme == .dark ? 0.10 : 0.07)))
    }
}
''' +s[b:]
s=s.replace('prominent ? Color.accentColor.opacity(0.18) : nil','nil').replace('Capsule().fill(tint.opacity(0.12))','Capsule().fill(.primary.opacity(0.10))')
p.write_text(s)
p=Path('outputs/Aster-macOS/Sources/Views.swift');s=p.read_text().replace('.tint(Color(red: 0.43, green: 0.39, blue: 0.78))','.tint(scheme == .dark ? .white : .black)')
s=s.replace('''                                    .fill(LinearGradient(colors: [store.agent.style.tint.color.opacity(scheme == .dark ? 0.3 : 0.23), .white.opacity(scheme == .dark ? 0.07 : 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing))''','''                                    .fill(.primary.opacity(scheme == .dark ? 0.12 : 0.075))''')
s=s.replace('.frame(width: 183).frame(maxHeight: .infinity).liquidSurface(25)','.frame(width: 183).frame(maxHeight: .infinity).frostedSurface(25)')
s=s.replace('Circle().fill(store.agent.style.tint.color.opacity(0.5))','Circle().fill(.primary.opacity(0.09))')
s=s.replace('.liquidSurface(21, tint: store.agent.id == agent.id ? agent.style.tint.color.opacity(0.16) : nil, interactive: true)','.frostedSurface(21)')
s=s.replace('store.agent.id == agent.id ? agent.style.tint.color.opacity(0.8) : .clear','store.agent.id == agent.id ? Color.primary.opacity(0.25) : .clear')
s=s.replace('Color.purple.opacity(0.13)','Color.black.opacity(0.1)').replace('LinearGradient(colors: [Color(red: 0.49, green: 0.46, blue: 0.83), Color(red: 0.35, green: 0.32, blue: 0.67)], startPoint: .topLeading, endPoint: .bottomTrailing)','LinearGradient(colors: [Color(white: 0.28), Color(white: 0.13)], startPoint: .topLeading, endPoint: .bottomTrailing)')
s=s.replace('.padding(.horizontal, 15).padding(.vertical, 13).liquidSurface(25)','.padding(.horizontal, 15).padding(.vertical, 13).frostedSurface(25)')
s=s.replace('Color.accentColor.opacity(0.12)','Color.primary.opacity(0.075)').replace('Color.accentColor.opacity(0.055)','Color.primary.opacity(0.045)')
p.write_text(s)
p=Path('outputs/Aster-macOS/Sources/Avatar.swift');s=p.read_text().replace('dimension >= 120 ? 1.0 / 60 : 1.0 / 30','dimension >= 120 ? 1.0 / 30 : 1.0 / 15');p.write_text(s)
p=Path('outputs/Aster-macOS/Sources/App.swift');s=p.read_text().replace('companion.setContentSize(NSSize(width: size, height: size + 25))','if abs(companion.frame.width - size) > 1 { companion.setContentSize(NSSize(width: size, height: size + 25)) }')
s=s.replace('    @objc func quit()', '    func applicationWillTerminate(_ notification: Notification) { store.flushStorage() }\n    @objc func quit()');p.write_text(s)
p=Path('outputs/Aster-macOS/Sources/Store.swift');s=p.read_text().replace('    private let file: URL','    private let file: URL\n    private let writer = SnapshotWriter()')
s=s.replace('''    private func persist() throws { try JSONEncoder().encode(state).write(to: file, options: [.atomic]) }
    func save() {
        do { try persist(); onFloatingChange?() }
        catch { notice = "No se han podido guardar los cambios: \\(error.localizedDescription)" }
    }''','''    private func persist() throws { try writer.writeSynchronously(state, to: file) }
    func flushStorage() { do { try persist() } catch { notice = error.localizedDescription } }
    func save() {
        writer.write(state, to: file) { [weak self] error in Task { @MainActor in self?.notice = "No se han podido guardar los cambios: " + error.localizedDescription } }
        onFloatingChange?()
    }''')
s+='''\nprivate final class SnapshotWriter: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.aster.storage", qos: .utility)
    func write(_ state: SavedState, to file: URL, error: @escaping (Error) -> Void) {
        queue.async { do { try JSONEncoder().encode(state).write(to: file, options: .atomic) } catch let failure { error(failure) } }
    }
    func writeSynchronously(_ state: SavedState, to file: URL) throws { try queue.sync { try JSONEncoder().encode(state).write(to: file, options: .atomic) } }
}
'''
p.write_text(s)
