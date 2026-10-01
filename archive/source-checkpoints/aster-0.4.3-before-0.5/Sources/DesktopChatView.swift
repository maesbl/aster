import AppKit
import SwiftUI

struct DesktopFoldView: View {
    @ObservedObject var desktop: DesktopCompanions
    @EnvironmentObject var store: AsterStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("AsterAppearance") private var appearance = AsterAppearance.system.rawValue
    @AppStorage("AsterLanguage") private var language = "es"
    var body: some View {
        Button { withAnimation(AsterMotion.spring(reduceMotion)) { desktop.toggleCollapsed() } } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)).rotationEffect(.degrees(desktop.collapsed ? 0 : 180))
                if store.busy { Circle().fill(.primary).frame(width: 4, height: 4) }
                else if desktop.collapsed { Text("\(desktop.visibleCount)").font(.system(size: 9, weight: .medium)) }
            }.frame(width: 40, height: 28).liquidSurface(16, interactive: true)
        }.buttonStyle(FluidButtonStyle()).padding(2)
            .accessibilityLabel(L(desktop.collapsed ? "Desplegar compañeros" : "Minimizar compañeros"))
            .help(L(desktop.collapsed ? "Mostrar tu equipo" : "Recoger todo el equipo en esta flecha"))
            .contextMenu { Button(L("Mostrar compañeros")) { desktop.showAll() }; Button(L("Ordenar arriba a la derecha")) { desktop.arrange() } }
            .environment(\.locale, Locale(identifier: language)).preferredColorScheme(AsterAppearance(rawValue: appearance)?.scheme)
    }
}

struct DesktopChatView: View {
    @ObservedObject var desktop: DesktopCompanions
    @EnvironmentObject var store: AsterStore
    @AppStorage("AsterAppearance") private var appearance = AsterAppearance.system.rawValue
    @AppStorage("AsterLanguage") private var language = "es"
    @Environment(\.colorScheme) private var colorScheme
    @State private var following = true
    @State private var scrollHeight: CGFloat = 0
    private var agentID: String { desktop.activeChatID ?? "director" }
    private var agent: Specialist { store.state.specialists.first { $0.id == agentID } ?? Specialist.defaults[0] }
    private var mission: Mission? { store.desktopMission(for: agentID) }
    private var working: Bool { store.busy && store.activeMissionID == mission?.id }
    private var recovering: Bool { ["Por recuperar", "Cancelación pendiente"].contains(mission?.status ?? "") }
    private var draft: Binding<String> { Binding(get: { desktop.drafts[agentID] ?? "" }, set: { desktop.setDraft($0, agentID: agentID) }) }
    private var lastAnswer: String { mission?.messages.last(where: { $0.role == "assistant" })?.text ?? "" }
    private var changes: String { "\(mission?.id.uuidString ?? "new")-\(mission?.messages.count ?? 0)-\(lastAnswer.count)" }
    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 12).padding(.vertical, 10)
            Divider().opacity(0.5)
            transcript.frame(maxWidth: .infinity, maxHeight: .infinity)
            if let error = mission?.error, !error.isEmpty {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "exclamationmark.circle").font(.system(size: 11))
                    Text(L(error)).font(.system(size: 10)).lineLimit(3)
                    Spacer(minLength: 0)
                    if recovering, let id = mission?.id { Button(L("Recuperar")) { store.recover(missionID: id) }.disabled(store.busy).font(.system(size: 10, weight: .semibold)) }
                }.padding(10).background(.primary.opacity(0.04))
            }
            if store.busy, !working {
                Text(L("Otro agente está trabajando. Tu borrador se conserva.")).font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 14).padding(.bottom, 5)
            }
            if let files = mission?.artifactRecords, !files.isEmpty {
                Button { desktop.expandChat() } label: { Label(LF("%d archivos · abrir conversación", files.count), systemImage: "doc.on.doc").font(.system(size: 10, weight: .medium)) }
                    .buttonStyle(.plain).padding(.horizontal, 14).padding(.bottom, 7)
            }
            composer.padding(10)
        }.background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 23))
            .overlay(RoundedRectangle(cornerRadius: 23).strokeBorder(.primary.opacity(0.10)))
            .clipShape(RoundedRectangle(cornerRadius: 23)).padding(1)
            .environment(\.locale, Locale(identifier: language)).preferredColorScheme(AsterAppearance(rawValue: appearance)?.scheme)
            .onChange(of: agentID) { _, _ in following = true }
            .onExitCommand { desktop.closeChat() }
    }
    private var header: some View {
        HStack(spacing: 9) {
            CompanionAvatar(style: agent.style, dimension: 26, animateAtRest: false, framesPerSecond: 24).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(agent.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                Text(working ? L("Trabajando contigo") : L(agent.role)).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 3)
            icon("plus", "Nueva conversación") { store.newDesktopConversation(agentID: agentID) }.disabled(working)
            icon(desktop.pinned ? "pin.fill" : "pin", desktop.pinned ? "Soltar minichat" : "Fijar minichat") { desktop.togglePin() }
            icon("arrow.up.right", "Abrir conversación completa") { desktop.expandChat() }
            icon("xmark", "Cerrar minichat") { desktop.closeChat() }
        }
    }
    private func icon(_ symbol: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 10, weight: .medium)).frame(width: 24, height: 26) }
            .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel(L(title)).help(L(title))
    }
    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    if mission?.messages.isEmpty != false {
                        VStack(alignment: .leading, spacing: 13) {
                            Text(LF("Habla con %@", agent.name)).font(.system(size: 19, weight: .semibold, design: .rounded))
                            Text(L("Ideas, preguntas y tareas, desde tu escritorio.")).font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3)
                            VStack(alignment: .leading, spacing: 7) {
                                ForEach(prompts, id: \.0) { title, prompt in
                                    Button { desktop.setDraft(L(prompt), agentID: agentID); desktop.focusInput() } label: {
                                        HStack { Text(L(title)); Spacer(); Image(systemName: "arrow.up.left").font(.system(size: 9)) }
                                            .font(.system(size: 11)).padding(10).background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
                                    }.buttonStyle(.plain)
                                }
                            }.padding(.top, 3)
                        }.padding(.top, 9)
                    }
                    ForEach(mission?.messages ?? []) { message in
                        if !message.text.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(message.role == "user" ? L("Tú") : agent.name).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                                if message.role == "user" { Text(verbatim: message.text).font(.system(size: 12)).lineSpacing(3).textSelection(.enabled) }
                                else { RichMessage(text: message.text).equatable() }
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(message.role == "user" ? 11 : 0)
                                .background(message.role == "user" ? Color.primary.opacity(0.045) : .clear, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    if working {
                        HStack(spacing: 8) { ProgressView().controlSize(.mini); Text(L(store.activity.isEmpty ? "Pensando" : store.activity)).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2) }
                    } else if !lastAnswer.isEmpty {
                        HStack(spacing: 13) {
                            Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(lastAnswer, forType: .string) } label: { Label(L("Copiar"), systemImage: "doc.on.doc") }
                            Button { store.speak(lastAnswer, agentID: agentID) } label: { Label(L(store.speaking ? "Detener voz" : "Escuchar"), systemImage: store.speaking ? "stop.fill" : "speaker.wave.2") }
                        }.font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                    Color.clear.frame(height: 1).id("desktop-bottom").background(GeometryReader { geometry in
                        Color.clear.preference(key: DesktopChatBottomKey.self, value: geometry.frame(in: .named("desktop-scroll")).maxY)
                    })
                }.padding(14)
            }.coordinateSpace(name: "desktop-scroll").background(GeometryReader { geometry in Color.clear.onAppear { scrollHeight = geometry.size.height }.onChange(of: geometry.size.height) { _, value in scrollHeight = value } })
                .onPreferenceChange(DesktopChatBottomKey.self) { bottom in if scrollHeight > 0 { following = bottom <= scrollHeight + 70 } }
                .onChange(of: changes) { _, _ in if following { proxy.scrollTo("desktop-bottom", anchor: .bottom) } }
                .onChange(of: agentID) { _, _ in proxy.scrollTo("desktop-bottom", anchor: .bottom) }
                .overlay(alignment: .bottomTrailing) {
                    if !following { Button { following = true; proxy.scrollTo("desktop-bottom", anchor: .bottom) } label: { Image(systemName: "arrow.down").font(.system(size: 11)).frame(width: 28, height: 28).liquidSurface(15, interactive: true) }.buttonStyle(.plain).accessibilityLabel(L("Ir al último mensaje")).padding(10) }
                }
        }
    }
    private var composer: some View {
        VStack(spacing: 7) {
            HStack(alignment: .bottom, spacing: 8) {
                DesktopComposer(text: draft, placeholder: LF("Mensaje para %@…", agent.name), send: { desktop.send() }, close: { desktop.closeChat() }, editing: { desktop.pinned = true })
                    .frame(minHeight: 36, maxHeight: 48)
                if working {
                    Button { store.stop() } label: { Image(systemName: "stop.fill").font(.system(size: 10)).frame(width: 30, height: 30).liquidSurface(16, interactive: true) }
                        .buttonStyle(.plain).accessibilityLabel(L("Detener"))
                } else {
                    Button { desktop.send() } label: { Image(systemName: "arrow.up").font(.system(size: 12, weight: .semibold)).frame(width: 30, height: 30).background(Color.primary, in: Circle()).foregroundStyle(Color(nsColor: .windowBackgroundColor)) }
                        .buttonStyle(.plain).disabled(store.busy || recovering || draft.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel(LF("Enviar mensaje a %@", agent.name))
                }
            }.padding(10).background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 17))
            HStack { Text(L("↵ enviar · ⇧↵ nueva línea · esc cerrar")).font(.system(size: 9)).foregroundStyle(.secondary); Spacer(minLength: 0) }
        }
    }
    private var prompts: [(String, String)] {
        switch agentID {
        case "growth": return [("Una campaña", "Ayúdame a preparar una campaña de marketing. Pregúntame lo imprescindible para empezar."), ("Mejorar un texto", "Quiero mejorar un texto de marketing. Ayúdame a hacerlo claro y convincente.")]
        case "builder": return [("Construir una web", "Ayúdame a crear una web. Definamos primero qué tiene que hacer."), ("Resolver un problema", "Ayúdame a resolver un problema técnico paso a paso.")]
        case "strategy": return [("Un plan de negocio", "Ayúdame a preparar un plan de negocio con supuestos claros y próximos pasos."), ("Tomar una decisión", "Ayúdame a comparar mis opciones para tomar una decisión.")]
        case "personal": return [("Ordenar mi día", "Ayúdame a organizar mis prioridades de hoy."), ("Pensar juntos", "Quiero pensar contigo sobre una idea y encontrar un próximo paso.")]
        case "study": return [("Entender una tarea", "Ayúdame a entender una tarea de clase y resolverla paso a paso."), ("Preparar un examen", "Ayúdame a preparar un examen. Hagamos un plan y preguntas de práctica.")]
        default: return [("Pensar una idea", "Ayúdame a desarrollar una idea y convertirla en algo concreto."), ("Mi próximo paso", "Ayúdame a decidir en qué debería centrarme ahora.")]
        }
    }
}

private struct DesktopChatBottomKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct DesktopComposer: NSViewRepresentable {
    @Binding var text: String
    @Environment(\.colorScheme) private var colorScheme
    var placeholder: String
    var send: () -> Void
    var close: () -> Void
    var editing: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView(); scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        scroll.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        let editor = Editor(); editor.isRichText = false; editor.drawsBackground = false; editor.font = .systemFont(ofSize: 12)
        editor.textColor = .labelColor; editor.insertionPointColor = .labelColor; editor.textContainerInset = NSSize(width: 1, height: 5)
        editor.isVerticallyResizable = true; editor.isHorizontallyResizable = false; editor.autoresizingMask = [.width]
        editor.minSize = NSSize(width: 0, height: 42); editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.textContainer?.widthTracksTextView = true; editor.delegate = context.coordinator
        editor.onSend = send; editor.onClose = close; editor.onEditing = editing; editor.placeholder = placeholder
        editor.setAccessibilityLabel(placeholder); scroll.documentView = editor
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let editor = scroll.documentView as? Editor else { return }
        scroll.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        context.coordinator.parent = self
        if editor.string != text { editor.string = text; editor.setSelectedRange(NSRange(location: (text as NSString).length, length: 0)) }
        editor.onSend = send; editor.onClose = close; editor.onEditing = editing; editor.placeholder = placeholder
        editor.textColor = .labelColor; editor.insertionPointColor = .labelColor; editor.setAccessibilityLabel(placeholder); editor.needsDisplay = true
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: DesktopComposer
        init(_ parent: DesktopComposer) { self.parent = parent }
        func textDidChange(_ notification: Notification) { if let editor = notification.object as? NSTextView { parent.text = editor.string } }
    }
    final class Editor: NSTextView {
        var onSend: () -> Void = {}; var onClose: () -> Void = {}; var onEditing: () -> Void = {}
        var placeholder = ""
        override var needsPanelToBecomeKey: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func becomeFirstResponder() -> Bool { let result = super.becomeFirstResponder(); if result { onEditing() }; return result }
        override func keyDown(with event: NSEvent) {
            if !hasMarkedText(), event.keyCode == 36 || event.keyCode == 76 {
                if event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.option) { super.keyDown(with: event) } else { onSend() }; return
            }
            if !hasMarkedText(), event.keyCode == 53 { onClose(); return }
            super.keyDown(with: event)
        }
        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            if string.isEmpty { (placeholder as NSString).draw(at: NSPoint(x: 6, y: 5), withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.placeholderTextColor]) }
        }
    }
}
