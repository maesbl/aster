import SwiftUI

struct MacView: View {
    @EnvironmentObject var model: PhoneModel
    @State private var task = ""
    @State private var reply = ""
    @State private var agentID = "study"
    @State private var manual = false
    @State private var draw = false
    @State private var typedText = ""
    @State private var appName = ""
    @State private var points: [RemotePoint] = []
    @State private var touchFrame: UUID?
    private var canControl: Bool { model.online && model.snapshot?.canControlRemotely == true && model.snapshot?.controlAllowed == true }
    private var canTouch: Bool { manual && canControl && model.frameFresh && model.snapshot?.computerActive != true }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack { VStack(alignment: .leading, spacing: 5) { Text("Tu Mac, aquí.").font(.system(size: 28, weight: .semibold, design: .rounded)).tracking(-0.8); Text(model.screenVisible ? "La imagen se actualiza mientras estás aquí." : "Abre la pantalla cuando la necesites.").font(.caption).foregroundStyle(.secondary) }; Spacer() }
                screen
                HStack {
                    Button { model.showScreen(!model.screenVisible) } label: { Label(model.screenVisible ? "Cerrar pantalla" : "Ver pantalla", systemImage: model.screenVisible ? "eye.slash" : "eye") }.buttonStyle(.bordered).disabled(!model.online)
                    Spacer()
                    if model.frameFresh { Label("En directo", systemImage: "circle.fill").font(.caption2).foregroundStyle(.green) }
                    else if model.screenVisible { Text("Esperando imagen…").font(.caption).foregroundStyle(.secondary) }
                }
                if model.snapshot?.canControlRemotely == false || model.snapshot?.controlAllowed == false { Label("Activa el control remoto y Accesibilidad en Aster para usar el ordenador desde aquí.", systemImage: "hand.raised").font(.footnote).foregroundStyle(.secondary) }
                VStack(alignment: .leading, spacing: 14) {
                    HStack { Text("Díselo y lo hace").font(.headline); Spacer(); Picker("Agente", selection: $agentID) { ForEach(model.snapshot?.agents ?? []) { Text($0.name).tag($0.id) } }.labelsHidden() }
                    TextField("Por ejemplo: abre Numbers y prepara una tabla para mis gastos", text: $task, axis: .vertical).lineLimit(3...6).padding(14).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                    Button { Task { if await model.send(.init(operation: .startComputer, text: task, agentID: agentID)) { task = "" } } } label: { Label("Hacerlo en mi Mac", systemImage: "cursorarrow.motionlines").frame(maxWidth: .infinity).padding(6) }.buttonStyle(.borderedProminent).tint(.white).foregroundStyle(.black).disabled(!canControl || task.isEmpty || model.snapshot?.computerActive == true)
                    if let state = model.snapshot, state.computerActive || !state.computerResult.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(state.computerPhase).font(.subheadline).foregroundStyle(.secondary)
                            if !state.computerQuestion.isEmpty { Text(state.computerQuestion).font(.subheadline) }
                            if state.computerPaused { TextField("Tu respuesta o una indicación", text: $reply, axis: .vertical).textFieldStyle(.roundedBorder) }
                            if state.computerActive {
                                HStack { Button(state.computerPaused ? "Continuar" : "Pausar") { Task { _ = await model.send(.init(operation: state.computerPaused ? .resumeComputer : .pauseComputer, text: reply)); reply = "" } }.buttonStyle(.bordered); Button("Detener", role: .destructive) { Task { _ = await model.send(.init(operation: .stopComputer)) } }.buttonStyle(.bordered) }.disabled(!model.online)
                            }
                            if !state.computerResult.isEmpty { Text(state.computerResult).font(.footnote).textSelection(.enabled) }
                        }
                    }
                }.padding(18).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 24))
                DisclosureGroup("Control manual", isExpanded: $manual) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text(model.snapshot?.computerActive == true ? "Detén la tarea del agente para usar el control manual." : "Toca la imagen para hacer clic. Activa Dibujar para trazar sobre el lienzo de una app que tengas abierta.").font(.caption).foregroundStyle(.secondary)
                        Toggle("Dibujar con el dedo", isOn: $draw).tint(.gray)
                        HStack { Button { sendInput(action: "scroll", direction: "up") } label: { Image(systemName: "arrow.up") }; Button { sendInput(action: "scroll", direction: "down") } label: { Image(systemName: "arrow.down") }; Spacer(); Button("Esc") { sendInput(action: "key", key: "escape") }; Button("↵") { sendInput(action: "key", key: "return") } }.buttonStyle(.bordered)
                        HStack { TextField("Escribir en el Mac", text: $typedText, axis: .vertical).lineLimit(1...4).textFieldStyle(.roundedBorder); Button("Enviar") { sendInput(action: "type", text: typedText); typedText = "" }.disabled(typedText.isEmpty) }
                        HStack { TextField("Nombre de una app", text: $appName).textFieldStyle(.roundedBorder); Button("Abrir") { sendInput(action: "open_app", app: appName) }.disabled(appName.isEmpty) }
                    }.padding(.top, 16).disabled(!canTouch)
                }.padding(18).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 24))
            }.padding(20)
        }.navigationTitle("Mi Mac").navigationBarTitleDisplayMode(.inline).background(Color(white: 0.025)).onDisappear { model.showScreen(false) }
    }
    private var screen: some View {
        Group {
            if let image = model.frameImage, let frame = model.frame, model.screenVisible {
                GeometryReader { geometry in
                    Image(uiImage: image).resizable().scaledToFit().opacity(model.frameFresh ? 1 : 0.35)
                        .overlay {
                            if !points.isEmpty { Path { path in for (index, point) in points.enumerated() { let p = CGPoint(x: point.x * geometry.size.width, y: point.y * geometry.size.height); if index == 0 { path.move(to: p) } else { path.addLine(to: p) } } }.stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round)).allowsHitTesting(false) }
                        }
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                            guard canTouch else { return }
                            if points.isEmpty { touchFrame = frame.id }
                            let p = RemotePoint(x: min(0.9999, max(0, value.location.x / geometry.size.width)), y: min(0.9999, max(0, value.location.y / geometry.size.height)))
                            if draw && points.count < 128 { points.append(p) } else if !draw { points = [p] }
                        }.onEnded { _ in
                            defer { points = []; touchFrame = nil }
                            guard canTouch, let point = points.last, let id = touchFrame else { return }
                            if draw && points.count > 1 { model.input(.init(action: "drag", frameID: id, path: points)) }
                            else { model.input(.init(action: "click", frameID: id, x: point.x, y: point.y)) }
                        })
                }.aspectRatio(CGFloat(frame.width) / CGFloat(frame.height), contentMode: .fit)
            } else {
                VStack(spacing: 12) { Image(systemName: "desktopcomputer").font(.system(size: 42, weight: .ultraLight)); Text(model.screenVisible ? "Conectando con la pantalla…" : "Tu pantalla se comparte al abrirla").font(.caption) }.foregroundStyle(.secondary).frame(maxWidth: .infinity).frame(height: 210).background(.white.opacity(0.035))
            }
        }.clipShape(RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.1)))
    }
    private func sendInput(action: String, text: String? = nil, key: String? = nil, direction: String? = nil, app: String? = nil) {
        guard canTouch, let frame = model.frame else { return }
        model.input(.init(action: action, frameID: frame.id, text: text, key: key, direction: direction, app: app))
    }
}
struct ActivityView: View {
    @EnvironmentObject var model: PhoneModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !model.pending.isEmpty {
                    Text("Por confirmar").font(.headline)
                    ForEach(Array(model.pending.values).sorted(by: { $0.date > $1.date })) { item in VStack(alignment: .leading, spacing: 7) { Label(item.message, systemImage: "clock").font(.footnote); Text(item.date, style: .time).font(.caption2).foregroundStyle(.secondary) }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16)) }
                    Text("Aster no reenvía una orden dudosa. Abre su conversación o comprueba la pantalla antes de pedirla otra vez.").font(.caption).foregroundStyle(.secondary)
                }
                if (model.snapshot?.missions ?? []).isEmpty { ContentUnavailableView("Tu actividad aparecerá aquí", systemImage: "waveform.path", description: Text("Pide una tarea a un agente desde el iPhone o el Mac.")) }
                else { ForEach(model.snapshot?.missions ?? []) { mission in MissionRow(mission: mission) } }
            }.padding(20)
        }.navigationTitle("Actividad").background(Color(white: 0.025))
    }
}
struct PhoneSettingsView: View {
    @EnvironmentObject var model: PhoneModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirm = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Tu Mac") { LabeledContent("Nombre", value: model.pairing?.name ?? "Sin enlazar"); LabeledContent("Estado", value: model.online ? "Conectado" : model.connection.status); Text("El enlace es privado entre tu Mac y tu iPhone. El servidor de enlace no puede leer tus conversaciones ni tu pantalla.").font(.footnote).foregroundStyle(.secondary) }
                Section("Disponibilidad") { Text("Deja Aster abierto en el Mac y activa el acceso desde el iPhone. La pantalla y el control requieren que el Mac esté desbloqueado. Cuando el iPhone pierde la conexión, una tarea de control del ordenador se pausa; las conversaciones de los agentes pueden continuar en el Mac.").font(.footnote) }
                Section { Button("Olvidar este Mac", role: .destructive) { confirm = true }; Text("Para invalidar también el código anterior, usa «Desvincular iPhone» en Aster para Mac.").font(.caption).foregroundStyle(.secondary) }
                Section { Text("Aster Remote 0.6 · Vista previa\niPhone con iOS 17 o posterior").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("Ajustes").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } } }
                .confirmationDialog("¿Olvidar este Mac?", isPresented: $confirm) { Button("Olvidar", role: .destructive) { model.forget(); dismiss() } }
        }
    }
}
