import SwiftUI
import AppKit
import Combine

struct ComputerWorkspaceView: View {
    @EnvironmentObject var store: AsterStore
    @ObservedObject var computer: ComputerController
    @State private var task = ""
    @State private var answer = ""
    @State private var agentID = "study"
    private let permissionRefresh = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(L("Una mano en tu Mac.")).font(.system(size: 30, weight: .semibold, design: .rounded)).tracking(-0.8)
                        Text(L("Estudia, crea y trabaja con tus apps. Mira cada paso.")).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if computer.active { GlassAction(title: "Detener", symbol: "stop.fill", action: { computer.stop() }) }
                }
                HStack(spacing: 16) {
                    Image(systemName: "cursorarrow.rays").font(.system(size: 25))
                    VStack(alignment: .leading, spacing: 5) { Text(L("A tu lado")).font(.system(size: 15, weight: .semibold)); Text(L("Un compañero junto al cursor. Explicaciones, dibujos y tareas sobre tu pantalla.")).font(.system(size: 11)).foregroundStyle(.secondary); Text("⌥⌘K").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary) }
                    Spacer(); GlassAction(title: "Abrir A tu lado", symbol: "sparkles") { store.onOpenCoach?() }.disabled(computer.active)
                }.padding(20).frostedSurface(21)
                ScreenLiveView(preview: computer.preview, screenAllowed: computer.screenAllowed)
                HStack(spacing: 12) {
                    Label(L(computer.phase), systemImage: computer.active ? computer.paused ? "pause.circle" : "cursorarrow.motionlines" : "cursorarrow").font(.system(size: 12, weight: .medium)).lineLimit(2)
                    Spacer()
                    if computer.active {
                        GlassAction(title: computer.paused ? "Continuar" : "Pausar", symbol: computer.paused ? "play.fill" : "pause.fill") { computer.paused ? computer.resume() : computer.pause() }.disabled(!computer.question.isEmpty)
                    } else {
                        Picker(L("Pantalla"), selection: $computer.selectedDisplay) { ForEach(Array(NSScreen.screens.enumerated()), id: \.offset) { index, screen in Text(screen.localizedName).tag((screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID()) } }.frame(maxWidth: 190).labelsHidden().onChange(of: computer.selectedDisplay) { _, _ in if computer.preview.connected { computer.showPreview() } }
                        GlassAction(title: computer.preview.connected ? "Ocultar pantalla" : "Ver pantalla", symbol: "display") { computer.preview.connected ? computer.hidePreview() : computer.showPreview() }.disabled(!computer.screenAllowed)
                    }
                }
                if !computer.screenAllowed || !computer.controlAllowed { permissions }
                if !computer.error.isEmpty { Text(L(computer.error)).font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(4).padding(16).frame(maxWidth: .infinity, alignment: .leading).frostedSurface(17) }
                if !computer.question.isEmpty {
                    VStack(alignment: .leading, spacing: 13) {
                        Text(computer.question).font(.system(size: 13, weight: .medium)).textSelection(.enabled)
                        TextField(L("Tu respuesta o indicación…"), text: $answer, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(1...5)
                        HStack { Text(L("Puedes realizar tú el paso pendiente y después continuar.")).font(.system(size: 10)).foregroundStyle(.secondary); Spacer(); GlassAction(title: "Continuar con mi respuesta", symbol: "arrow.right") { computer.resume(answer); answer = "" }.disabled(answer.isEmpty) }
                    }.padding(20).frostedSurface(21)
                }
                if !computer.active { taskComposer }
                if !computer.steps.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L("Lo que está haciendo")).font(.system(size: 13, weight: .semibold))
                        ForEach(Array(computer.steps.suffix(12))) { step in HStack(alignment: .top, spacing: 10) { Image(systemName: step.action == "error" ? "exclamationmark.circle" : step.action == "finish" ? "checkmark.circle" : "circle.fill").font(.system(size: step.action == "error" || step.action == "finish" ? 12 : 5)).frame(width: 15, height: 17).foregroundStyle(.secondary); Text(step.text).font(.system(size: 12)).lineSpacing(4).textSelection(.enabled); Spacer(); Text(step.date.formatted(date: .omitted, time: .shortened)).font(.system(size: 9)).foregroundStyle(.tertiary) } }
                        if !computer.result.isEmpty { Divider(); RichMessage(text: computer.result) }
                    }.padding(20).frostedSurface(21)
                }
                if !store.state.computerRuns.isEmpty {
                    Text(L("Tus últimas tareas en el Mac")).font(.system(size: 13, weight: .semibold)).padding(.top, 5)
                    ForEach(Array(store.state.computerRuns.prefix(8))) { run in
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 9) { ForEach(run.steps) { Text($0.text).font(.system(size: 11)).foregroundStyle(.secondary) }; if !run.result.isEmpty { RichMessage(text: run.result) } }.padding(.vertical, 12).textSelection(.enabled)
                        } label: { HStack { Text(run.task).font(.system(size: 12, weight: .medium)).lineLimit(1); Spacer(); Text(L(run.status)).font(.system(size: 10)).foregroundStyle(.secondary) } }.padding(17).frostedSurface(19)
                    }
                }
            }.padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 26)
        }.scrollIndicators(.hidden).onAppear { computer.refreshPermissions() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in computer.refreshPermissions() }
        .onReceive(permissionRefresh) { _ in if !computer.active { computer.refreshPermissions() } }
    }
    private var taskComposer: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text(L("¿Qué hacemos juntos?")).font(.system(size: 15, weight: .semibold)); Spacer(); Picker(L("Compañero"), selection: $agentID) { ForEach(store.state.specialists) { Text($0.name).tag($0.id) } }.frame(width: 150) }
            TextEditor(text: $task).font(.system(size: 14)).scrollContentBackground(.hidden).frame(height: 70).padding(10).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12)).accessibilityLabel(L("Tarea para el ordenador"))
            HStack(spacing: 8) {
                Button(L("Una hoja de Excel")) { task = L("Abre Excel y crea una hoja nueva con una tabla de presupuesto mensual. Añade ingresos, gastos, totales y fórmulas. Explícame cada paso y comprueba los resultados.") }
                Button(L("Estudiar conmigo")) { task = L("Ayúdame con la tarea que tengo abierta. Lee las instrucciones, explícame cómo resolverla y prepara el trabajo en la app, paso a paso.") }
                Spacer()
            }.font(.system(size: 10)).glassControl()
            HStack {
                VStack(alignment: .leading, spacing: 4) { Text(L("Aster verá la pantalla y usará el cursor durante esta tarea.")).font(.system(size: 10)); Text(L("La pantalla de esta tarea se envía a OpenAI. Esc detiene el control.")).font(.system(size: 9)).foregroundStyle(.secondary) }
                Spacer()
                GlassAction(title: "Empezar en mi Mac", symbol: "cursorarrow.motionlines", prominent: true) { guard let agent = store.state.specialists.first(where: { $0.id == agentID }) else { return }; computer.start(task, agent: agent, settings: store.settings) }.disabled(task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !computer.screenAllowed || !computer.controlAllowed)
            }
        }.padding(22).frostedSurface(23)
    }
    private var permissions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L("Conecta tu Mac"), systemImage: "macbook").font(.system(size: 14, weight: .semibold))
            HStack(spacing: 20) {
                permission("Pantalla", detail: "Para ver lo que tienes abierto", granted: computer.screenAllowed, action: computer.requestScreen)
                permission("Accesibilidad", detail: "Para mover el cursor y escribir", granted: computer.controlAllowed, action: computer.requestControl)
            }
            Text(L("Activa Aster en Ajustes del Sistema → Privacidad y seguridad. Si macOS pide reiniciar Aster, vuelve a abrirlo después.")).font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(4)
            VStack(alignment: .leading, spacing: 8) {
                Text(L("¿Está activado en Ajustes pero sigue pendiente aquí?")).font(.system(size: 11, weight: .medium))
                Text(L("Puede quedar una autorización de otra compilación. Cierra Aster, elimina su entrada antigua con − y añade esta copia con +. Después vuelve a abrir Aster.")).font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(3)
                HStack(alignment: .top) {
                    Text(Bundle.main.bundleURL.path).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled).lineLimit(3)
                    Spacer()
                    Button(L("Mostrar esta copia")) { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }.font(.system(size: 10))
                }
            }.padding(12).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
            HStack { Button(L("Abrir Privacidad y seguridad")) { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security")!) }; Button(L("Comprobar permisos"), action: computer.refreshPermissions); Spacer(); Picker(L("Pantalla"), selection: $computer.selectedDisplay) { ForEach(Array(NSScreen.screens.enumerated()), id: \.offset) { index, screen in Text(screen.localizedName).tag((screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID()) } }.frame(maxWidth: 220) }.font(.system(size: 11))
        }.padding(20).frostedSurface(21)
    }
    private func permission(_ title: String, detail: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack { Image(systemName: granted ? "checkmark.circle.fill" : "circle").foregroundStyle(.secondary); VStack(alignment: .leading, spacing: 4) { Text(L(title)).font(.system(size: 12, weight: .medium)); Text(L(detail)).font(.system(size: 10)).foregroundStyle(.secondary) }; Spacer(); if !granted { Button(L("Permitir"), action: action).font(.system(size: 11)) } }.frame(maxWidth: .infinity)
    }
}
struct ScreenLiveView: View {
    @ObservedObject var preview: ScreenPreview
    let screenAllowed: Bool
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 21).fill(Color(white: 0.045))
            if let image = preview.image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).padding(8)
            } else {
                VStack(spacing: 12) { Image(systemName: "display").font(.system(size: 29, weight: .light)); Text(L("Tu pantalla, en directo.")).font(.system(size: 15, weight: .medium)); Text(L(preview.error.isEmpty ? (screenAllowed ? "Pulsa Ver pantalla para abrir la vista en directo." : "Activa Pantalla para ver lo que hace tu compañero.") : preview.error)).font(.system(size: 11)).foregroundStyle(.white.opacity(0.45)).multilineTextAlignment(.center).frame(maxWidth: 420) }.foregroundStyle(.white.opacity(0.7)).padding(25)
            }
            if preview.connected { VStack { HStack { Spacer(); HStack(spacing: 6) { Circle().fill(.white).frame(width: 5, height: 5); Text(L("EN DIRECTO")).font(.system(size: 8, weight: .semibold)).tracking(1) }.padding(9).background(.black.opacity(0.65), in: Capsule()).padding(14) }; Spacer() } }
        }.frame(height: 270).clipShape(RoundedRectangle(cornerRadius: 21)).overlay(RoundedRectangle(cornerRadius: 21).strokeBorder(.primary.opacity(0.1)))
    }
}
struct ComputerHUD: View {
    @ObservedObject var computer: ComputerController
    var open: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: "cursorarrow.motionlines"); Text("Aster").font(.system(size: 12, weight: .semibold)); Spacer(); Button(action: open) { Image(systemName: "arrow.up.right") }.buttonStyle(.plain); Button { computer.pause() } label: { Image(systemName: "pause.fill") }.buttonStyle(.plain); Button { computer.stop() } label: { Image(systemName: "stop.fill") }.buttonStyle(.plain).accessibilityLabel(L("Detener control del Mac")) }
            Text(L(computer.phase)).font(.system(size: 11)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
        }.foregroundStyle(.white).padding(16).frame(width: 330, height: 102).background(Color(white: 0.1), in: RoundedRectangle(cornerRadius: 21)).overlay(RoundedRectangle(cornerRadius: 21).strokeBorder(.white.opacity(0.13))).padding(6)
    }
}
