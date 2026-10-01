import SwiftUI

@main struct AsterRemoteApp: App {
    @StateObject private var model = PhoneModel()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model).preferredColorScheme(.dark)
                .onOpenURL { model.pair($0.absoluteString) }
                .onChange(of: scenePhase) { _, phase in if phase == .active { model.resume() } else if phase == .background { model.suspend() } }
                .overlay { if scenePhase != .active { Color.black.ignoresSafeArea().overlay { Image(systemName: "sparkle").font(.system(size: 44)).foregroundStyle(.white) } } }
        }
    }
}
struct RootView: View {
    @EnvironmentObject var model: PhoneModel
    @State private var tab = 0
    @State private var settings = false
    var body: some View {
        Group {
            if model.pairing == nil && !model.verified { PairView() }
            else {
                TabView(selection: $tab) {
                    NavigationStack { TeamView().toolbar { ToolbarItem(placement: .topBarTrailing) { Button { settings = true } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("Ajustes") } } }.tabItem { Label("Equipo", systemImage: "circle.dotted.circle") }.tag(0)
                    NavigationStack { MacView() }.tabItem { Label("Mi Mac", systemImage: "desktopcomputer") }.tag(1)
                    NavigationStack { ActivityView() }.tabItem { Label("Actividad", systemImage: "waveform.path") }.tag(2)
                }.tint(.white)
                .sheet(isPresented: $settings) { PhoneSettingsView() }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if model.pairing != nil {
                HStack(spacing: 8) { Circle().fill(model.online ? Color.green : .orange).frame(width: 6, height: 6); Text(model.online ? (model.snapshot?.name ?? "Mac conectado") : model.connection.status).lineLimit(1); Spacer(); if !model.online { Button("Reconectar") { model.resume() } } }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.vertical, 9).background(.ultraThinMaterial)
            }
        }
        .alert("Aster", isPresented: Binding(get: { !model.message.isEmpty && model.pairing != nil }, set: { if !$0 { model.message = "" } })) { Button("Entendido") { model.message = "" } } message: { Text(model.message) }
    }
}
struct PairView: View {
    @EnvironmentObject var model: PhoneModel
    @State private var code = ""
    @State private var scan = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Spacer(minLength: 44)
                MiniCompanion(agentID: "director", size: 76)
                VStack(alignment: .leading, spacing: 12) { Text("Aster,\nsiempre contigo.").font(.system(size: 42, weight: .semibold, design: .rounded)).tracking(-1.8); Text("Tu equipo y tu Mac, en tu bolsillo.").font(.title3).foregroundStyle(.secondary) }
                VStack(alignment: .leading, spacing: 16) {
                    Label("Abre Aster en el Mac", systemImage: "macwindow")
                    Label("Ajustes → Conexiones → Enlazar mi iPhone", systemImage: "qrcode")
                    Label("Escanea el código para conectarlos", systemImage: "iphone")
                }.font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 12)
                Button { scan = true } label: { Label("Escanear el código", systemImage: "qrcode.viewfinder").frame(maxWidth: .infinity).padding(9) }.buttonStyle(.borderedProminent).tint(.white).foregroundStyle(.black).controlSize(.large)
                DisclosureGroup("O pegar un enlace") {
                    VStack(spacing: 12) { SecureField("aster://pair#…", text: $code).textInputAutocapitalization(.never).autocorrectionDisabled().padding(12).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12)); Button("Enlazar mi Mac") { model.pair(code); code = "" }.disabled(code.isEmpty) }.padding(.top, 14)
                }.font(.subheadline)
                if !model.message.isEmpty { Text(model.message).font(.footnote).foregroundStyle(.secondary) }
                Text("La conexión queda guardada en el Llavero del iPhone. Tu Mac debe estar encendido y conectado a Internet.").font(.footnote).foregroundStyle(.tertiary)
            }.padding(28)
        }.background(Color(white: 0.025)).sheet(isPresented: $scan) { QRScanner { value in scan = false; model.pair(value) }.ignoresSafeArea().overlay(alignment: .bottom) { Button("Cancelar") { scan = false }.buttonStyle(.borderedProminent).tint(.black).padding(40) } }
    }
}
struct MiniCompanion: View {
    var agentID: String; var size: CGFloat = 44
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * (agentID == "builder" || agentID == "study" ? 0.5 : 0.36)).fill(LinearGradient(colors: [.white.opacity(0.98), Color(white: agentID == "personal" ? 0.48 : 0.74)], startPoint: .topLeading, endPoint: .bottomTrailing))
            HStack(spacing: size * 0.14) { Capsule().frame(width: size * 0.045, height: size * 0.11); Capsule().frame(width: size * 0.045, height: size * 0.11) }.foregroundStyle(.black.opacity(0.75))
        }.frame(width: size * 0.82, height: size).rotationEffect(.degrees(agentID == "growth" ? -5 : 0)).shadow(color: .white.opacity(0.1), radius: size / 3)
    }
}
struct TeamView: View {
    @EnvironmentObject var model: PhoneModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 8) { Text("¿Qué hacemos hoy?").font(.system(size: 29, weight: .semibold, design: .rounded)).tracking(-0.9); Text("Una idea, una tarea o una empresa entera.").font(.subheadline).foregroundStyle(.secondary) }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(model.snapshot?.agents ?? []) { agent in
                        NavigationLink { ChatView(agent: agent, missionID: nil) } label: {
                            VStack(alignment: .leading, spacing: 15) {
                                HStack { MiniCompanion(agentID: agent.id); Spacer(); if agent.busy { Circle().fill(.green).frame(width: 6, height: 6) } }
                                VStack(alignment: .leading, spacing: 4) { Text(agent.name).font(.headline); Text(agent.role).font(.caption).foregroundStyle(.secondary) }
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 24))
                        }.buttonStyle(.plain)
                    }
                }
                if model.snapshot == nil { ContentUnavailableView("Conectando con tu equipo", systemImage: "antenna.radiowaves.left.and.right", description: Text("Abre Aster en el Mac y activa el acceso desde el iPhone.")) }
                if model.snapshot?.connectionReady == false { Label("Conecta OpenAI en los ajustes del Mac para iniciar tareas.", systemImage: "sparkle").font(.footnote).foregroundStyle(.secondary) }
                if let missions = model.snapshot?.missions, !missions.isEmpty {
                    Text("Continúa donde lo dejaste").font(.headline)
                    ForEach(Array(missions.prefix(6))) { mission in MissionRow(mission: mission) }
                }
            }.padding(20)
        }.navigationTitle("Aster").navigationBarTitleDisplayMode(.inline).background(Color(white: 0.025))
    }
}
struct MissionRow: View {
    @EnvironmentObject var model: PhoneModel
    let mission: RemoteMission
    var body: some View {
        if let agent = model.snapshot?.agents.first(where: { $0.id == mission.agentID }) {
            NavigationLink { ChatView(agent: agent, missionID: mission.id) } label: {
                HStack(spacing: 14) { MiniCompanion(agentID: agent.id, size: 28); VStack(alignment: .leading, spacing: 5) { Text(mission.title).font(.subheadline).lineLimit(2); Text(mission.activity.isEmpty ? mission.status : mission.activity).font(.caption).foregroundStyle(.secondary).lineLimit(1) }; Spacer(); Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary) }.padding(.vertical, 10)
            }.buttonStyle(.plain)
        }
    }
}
struct ChatView: View {
    @EnvironmentObject var model: PhoneModel
    let agent: RemoteAgent
    let missionID: UUID?
    @State private var currentID: UUID?
    @State private var text = ""
    @State private var companyID: UUID?
    @State private var sending = false
    @State private var awaitingID: UUID?
    @State private var sentText = ""
    private var mission: RemoteMission? { model.snapshot?.missions.first(where: { $0.id == currentID }) }
    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if currentID == nil {
                        MiniCompanion(agentID: agent.id, size: 60).padding(.top, 25)
                        Text("Hola, soy \(agent.name).").font(.title2.weight(.semibold))
                        Text("Cuéntame qué necesitas. Trabajaré con tu Aster del Mac y verás aquí el resultado.").foregroundStyle(.secondary)
                        Picker("Espacio", selection: $companyID) { Text("Personal").tag(UUID?.none); ForEach(model.snapshot?.companies ?? []) { Text($0.name).tag(Optional($0.id)) } }.pickerStyle(.menu)
                    }
                    if model.conversation?.id == currentID {
                        ForEach(model.conversation?.messages ?? []) { message in
                            VStack(alignment: .leading, spacing: 8) { Text(message.role == "user" ? "TÚ" : agent.name.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary); Text(message.text.isEmpty ? "Pensando…" : message.text).font(.body).textSelection(.enabled) }.padding(message.role == "user" ? 16 : 0).frame(maxWidth: .infinity, alignment: .leading).background(message.role == "user" ? .white.opacity(0.065) : .clear, in: RoundedRectangle(cornerRadius: 20))
                        }
                        if let error = model.conversation?.error, !error.isEmpty { Text(error).font(.footnote).foregroundStyle(.orange) }
                    }
                    if let awaitingID, let receipt = model.pending[awaitingID] { Label(receipt.message, systemImage: "clock").font(.caption).foregroundStyle(.secondary) }
                    Color.clear.frame(height: 1).id("bottom")
                }.padding(22)
            }.onChange(of: model.conversation?.messages.last?.text) { _, _ in withAnimation(.easeOut(duration: 0.15)) { scroll.scrollTo("bottom", anchor: .bottom) } }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if let mission, !mission.activity.isEmpty { HStack { ProgressView().controlSize(.mini); Text(mission.activity).font(.caption).lineLimit(1); Spacer(); Button("Detener") { Task { _ = await model.send(.init(operation: .stopMission, missionID: mission.id)) } }.font(.caption) }.padding(.horizontal, 5) }
                HStack(alignment: .bottom, spacing: 12) {
                    TextField("Habla con \(agent.name)…", text: $text, axis: .vertical).lineLimit(1...5).padding(13).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 19))
                    Button { send() } label: { Image(systemName: "arrow.up").font(.system(size: 19, weight: .semibold)).frame(width: 44, height: 44).background(.white, in: Circle()).foregroundStyle(.black) }.disabled(!model.online || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending || awaitingID != nil || mission?.status == "Trabajando").opacity(model.online ? 1 : 0.4)
                }
            }.padding(14).background(.ultraThinMaterial)
        }.navigationTitle(agent.name).navigationBarTitleDisplayMode(.inline).background(Color(white: 0.025))
        .onAppear { currentID = missionID; model.subscribe(missionID) }
        .onDisappear { model.subscribe(nil) }
        .onChange(of: model.lastReceipt?.id) { _, _ in
            guard let receipt = model.lastReceipt, receipt.id == awaitingID else { return }
            awaitingID = nil
            if receipt.status == "accepted" { if text == sentText { text = "" }; if let id = receipt.missionID { currentID = id; model.subscribe(id) } }
        }
    }
    private func send() {
        let command = RemoteCommand(operation: .chat, text: text, agentID: agent.id, missionID: currentID, companyID: companyID)
        awaitingID = command.id; sentText = text; sending = true
        Task { let sent = await model.send(command); sending = false; if !sent { awaitingID = nil } }
    }
}
