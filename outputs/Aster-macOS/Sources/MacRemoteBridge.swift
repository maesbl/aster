import AppKit
import Combine

@MainActor final class MacRemoteBridge: ObservableObject {
    let connection = RemoteConnection()
    @Published private(set) var pairing: RemotePairing?
    @Published private(set) var enabled = false
    @Published private(set) var sharing = false
    @Published var error = ""
    @Published var allowControl = UserDefaults.standard.bool(forKey: "AsterRemoteControl") {
        didSet { UserDefaults.standard.set(allowControl, forKey: "AsterRemoteControl"); if !allowControl && remoteComputer { store?.computer.stop(); remoteComputer = false } }
    }
    private weak var store: AsterStore?
    private let storageDirectory: URL?
    private let restoresConfiguration: Bool
    private let preview = ScreenPreview()
    private lazy var desktop = MacDesktop(preview: preview)
    private var stateJob: Task<Void, Never>?
    private var screenJob: Task<Void, Never>?
    private var screenStop: Task<Void, Never>?
    private var generation = UUID()
    private var frames: [UUID: (DesktopFrame, pid_t?, Date)] = [:]
    private var subscribed: UUID?
    private var ledger = RemoteLedger()
    private var remoteComputer = false
    private var token: AnyCancellable?
    private var awake: NSObjectProtocol?
    private var screenLease = Date.distantPast
    private var lockObservers: [NSObjectProtocol] = []
    private var screenLocked = false
    private var ledgerURL: URL? {
        guard let pairing else { return nil }
        return (storageDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Aster/Remote")).appendingPathComponent("\(pairing.room).json")
    }
    init(store: AsterStore, pairing: RemotePairing? = nil, storageDirectory: URL? = nil, restoresConfiguration: Bool = true) {
        self.store = store
        self.pairing = pairing; self.storageDirectory = storageDirectory; self.restoresConfiguration = restoresConfiguration
        do { if restoresConfiguration, let data = try CredentialVault.read("remote-mac-pairing") { self.pairing = try JSONDecoder().decode(RemotePairing.self, from: data); try self.pairing?.validate() } }
        catch { self.error = error.localizedDescription }
        token = connection.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
        connection.onPacket = { [weak self] packet in await self?.receive(packet) }
        connection.onPeerChange = { [weak self] online in
            guard let self else { return }
            if !online { self.endScreen(); if self.remoteComputer { self.store?.computer.pause() } }
            else { Task { await self.sendSnapshot() } }
        }
        for name in ["com.apple.screenIsLocked", "com.apple.screenIsUnlocked"] {
            lockObservers.append(DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name(name), object: nil, queue: .main) { [weak self] note in
                Task { @MainActor in guard let self else { return }; self.screenLocked = note.name.rawValue.hasSuffix("IsLocked"); if self.screenLocked { self.endScreen(); if self.remoteComputer { self.store?.computer.pause() } } }
            })
        }
        if restoresConfiguration, UserDefaults.standard.bool(forKey: "AsterRemoteEnabled"), self.pairing != nil { start() }
    }
    func createPairing(relay: String) {
        do {
            let candidate = try RemotePairing(relay: relay, name: Host.current().localizedName ?? "Mi Mac")
            try CredentialVault.save(JSONEncoder().encode(candidate), account: "remote-mac-pairing")
            stop(); pairing = candidate; ledger = RemoteLedger(); error = ""; start()
        } catch { self.error = error.localizedDescription }
    }
    func start() {
        guard let pairing, !enabled else { return }
        do {
            try pairing.validate()
            if let url = ledgerURL, FileManager.default.fileExists(atPath: url.path) { ledger = try JSONDecoder().decode(RemoteLedger.self, from: Data(contentsOf: url)) }
            enabled = true; error = ""; if restoresConfiguration { UserDefaults.standard.set(true, forKey: "AsterRemoteEnabled") }
            awake = ProcessInfo.processInfo.beginActivity(options: [.idleSystemSleepDisabled], reason: "Aster está disponible para tu iPhone")
            connection.connect(pairing, role: .mac)
            stateJob = Task { [weak self] in
                while !Task.isCancelled {
                    await self?.sendSnapshot()
                    try? await Task.sleep(for: .seconds(1)); guard !Task.isCancelled else { return }
                }
            }
        } catch { self.error = "No se ha activado el acceso remoto: " + error.localizedDescription }
    }
    func stop() {
        enabled = false; generation = UUID(); if restoresConfiguration { UserDefaults.standard.set(false, forKey: "AsterRemoteEnabled") }
        stateJob?.cancel(); stateJob = nil; endScreen(); connection.disconnect()
        if remoteComputer { store?.computer.stop(reason: "Acceso remoto desconectado"); remoteComputer = false }
        if let awake { ProcessInfo.processInfo.endActivity(awake); self.awake = nil }
    }
    func revoke() {
        do { try CredentialVault.remove("remote-mac-pairing"); stop(); pairing = nil; ledger = RemoteLedger(); error = "" }
        catch { self.error = error.localizedDescription }
    }
    func shutdown() { let wasEnabled = enabled; stop(); if restoresConfiguration { UserDefaults.standard.set(wasEnabled, forKey: "AsterRemoteEnabled") } }
    private func saveLedger() throws {
        guard let url = ledgerURL else { throw RemoteError.message("No hay un iPhone enlazado.") }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(ledger).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    private func receive(_ packet: RemotePacket) async {
        guard enabled, packet.kind == .command, let store else { return }
        let epoch = generation
        var command: RemoteCommand?
        do {
            let request = try packet.decode(RemoteCommand.self); command = request; try request.validate()
            if request.operation == .snapshot { await sendSnapshot(); return }
            if request.operation == .subscribe { subscribed = request.missionID; await sendSnapshot(); return }
            if request.operation == .screenStart {
                guard !screenLocked else { throw RemoteError.message("El Mac está bloqueado. Desbloquéalo para compartir la pantalla.") }
                screenLease = Date(); try await beginScreen(); return
            }
            if request.operation == .screenStop { endScreen(); return }
            if let old = try ledger.claim(request) { try await connection.send(.receipt, old); return }
            do { try saveLedger() } catch { ledger.receipts.removeAll { $0.id == request.id }; throw error }
            var receipt = RemoteReceipt(id: request.id, status: "accepted", message: "Orden recibida en el Mac.")
            switch request.operation {
            case .chat:
                guard store.connectionReady else { throw RemoteError.message("Conecta OpenAI en el Mac antes de iniciar una conversación.") }
                guard let agentID = request.agentID, store.state.specialists.contains(where: { $0.id == agentID }) else { throw RemoteError.message("Ese agente ya no está disponible.") }
                if let id = request.missionID { guard store.state.missions.contains(where: { $0.id == id && $0.specialistID == agentID }) else { throw RemoteError.message("La conversación no corresponde a ese agente.") } }
                if let id = request.companyID { guard store.companies.contains(where: { $0.id == id }) else { throw RemoteError.message("Esa empresa ya no está disponible.") } }
                guard store.run(request.text!, companyID: request.companyID, fresh: request.missionID == nil, missionID: request.missionID, specialistID: agentID, background: true) else { throw RemoteError.message("El agente está ocupado o la sesión necesita recuperarse en el Mac.") }
                receipt.missionID = request.missionID ?? store.state.missions.first?.id; subscribed = receipt.missionID
            case .stopMission:
                guard let id = request.missionID, store.isRunning(id) else { throw RemoteError.message("Esa misión ya no está en ejecución.") }
                store.stop(missionID: id); receipt.message = "Cancelación solicitada. Comprueba el estado de la misión."
            case .startComputer:
                try requireControl(); guard !store.computer.active else { throw RemoteError.message("El ordenador ya tiene una tarea en curso.") }
                guard let agent = store.state.specialists.first(where: { $0.id == request.agentID }) else { throw RemoteError.message("Elige un agente.") }
                guard store.connectionReady else { throw RemoteError.message("Conecta OpenAI en el Mac.") }
                store.computer.start(request.text!, agent: agent, settings: store.settings)
                guard store.computer.active else { throw RemoteError.message(store.computer.error) }; remoteComputer = true
            case .pauseComputer: store.computer.pause()
            case .resumeComputer: try requireControl(); store.computer.resume(request.text ?? ""); remoteComputer = true
            case .stopComputer: store.computer.stop(); remoteComputer = false
            case .input: try requireControl(); try await perform(request.input, epoch: epoch)
            default: break
            }
            guard generation == epoch else { return }
            ledger.finish(receipt); try saveLedger(); try await connection.send(.receipt, receipt); await sendSnapshot()
        } catch {
            guard generation == epoch, let command else { return }
            let receipt = RemoteReceipt(id: command.id, status: "error", message: error.localizedDescription)
            ledger.finish(receipt); try? saveLedger(); try? await connection.send(.receipt, receipt)
        }
    }
    private func requireControl() throws {
        guard enabled, allowControl, !screenLocked, MacDesktop.canSee, MacDesktop.canControl else { throw RemoteError.message("Activa «Permitir controlar este Mac» y los permisos de Pantalla y Accesibilidad en Aster. El Mac debe estar desbloqueado.") }
    }
    private func perform(_ input: RemoteInput?, epoch: UUID) async throws {
        guard store?.computer.active != true else { throw RemoteError.message("Detén la tarea del agente antes de usar el control manual.") }
        guard let input, let frameID = input.frameID, let (frame, app, date) = frames[frameID], Date().timeIntervalSince(date) < 5, sharing else { throw RemoteError.message("La imagen ha cambiado o ha caducado. Espera a la siguiente imagen.") }
        guard app == NSWorkspace.shared.frontmostApplication?.processIdentifier else { throw RemoteError.message("La app activa ha cambiado. Espera a la siguiente imagen.") }
        guard ["click", "double_click", "type", "key", "scroll", "open_app", "drag"].contains(input.action) else { throw RemoteError.message("Acción manual no disponible.") }
        func pixel(_ point: RemotePoint) throws -> ScreenPoint {
            guard point.x.isFinite, point.y.isFinite, point.x >= 0, point.x < 1, point.y >= 0, point.y < 1 else { throw RemoteError.message("El punto está fuera de la pantalla.") }
            return .init(x: point.x * Double(frame.geometry.imageWidth), y: point.y * Double(frame.geometry.imageHeight))
        }
        let point = try input.x.flatMap { x in try input.y.map { try pixel(.init(x: x, y: $0)) } }
        let path = try input.path?.map(pixel)
        let action = DesktopAction(action: input.action, explanation: "Control desde tu iPhone", x: point?.x, y: point?.y, text: input.text, key: input.key, direction: input.direction, app: input.app, path: path)
        frames.removeAll()
        try await desktop.perform(action, geometry: frame.geometry, allowed: { [weak self] in self?.enabled == true && self?.allowControl == true && self?.generation == epoch && self?.sharing == true && self?.connection.peerOnline == true && self?.screenLocked == false })
    }
    private func beginScreen() async throws {
        guard !sharing else { return }
        guard MacDesktop.canSee else { throw RemoteError.message("Activa el permiso de Pantalla en el Mac.") }
        let epoch = generation
        await screenStop?.value
        try await desktop.start(displayID: store?.computer.selectedDisplay ?? CGMainDisplayID())
        guard enabled, generation == epoch, connection.peerOnline else { await desktop.stop(); return }
        sharing = true
        screenJob = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, self.enabled, self.generation == epoch, self.sharing {
                do {
                    guard Date().timeIntervalSince(self.screenLease) < 12, !self.screenLocked else { self.endScreen(); return }
                    let frame = try await self.desktop.capture(includeAccessibility: false)
                    guard !Task.isCancelled, self.generation == epoch, self.sharing else { return }
                    let message = RemoteFrame(width: frame.geometry.imageWidth, height: frame.geometry.imageHeight, jpeg: frame.jpeg)
                    self.frames = self.frames.filter { Date().timeIntervalSince($0.value.2) < 5 }
                    self.frames[message.id] = (frame, NSWorkspace.shared.frontmostApplication?.processIdentifier, Date())
                    try await self.connection.send(.frame, message)
                    try await Task.sleep(for: .milliseconds(250))
                } catch { if !Task.isCancelled { self.error = error.localizedDescription; self.endScreen() }; return }
            }
        }
    }
    private func endScreen() {
        screenJob?.cancel(); screenJob = nil; sharing = false; frames.removeAll()
        let priorStop = screenStop
        screenStop = Task { await priorStop?.value; await desktop.stop(); try? await connection.send(.screenEnded, "La pantalla ha dejado de compartirse.") }
    }
    private func sendSnapshot() async {
        guard enabled, connection.peerOnline, let store else { return }
        let state = store.state
        var snapshot = RemoteSnapshot(name: pairing?.name ?? "Mac", agents: state.specialists.map { .init(id: $0.id, name: $0.name, role: $0.role, busy: store.isAgentWorking($0.id)) },
            missions: state.missions.filter { $0.archived != true }.prefix(60).map { .init(id: $0.id, title: String($0.title.prefix(180)), agentID: $0.specialistID, status: $0.status, activity: String(store.activity(for: $0.id).prefix(500)), updated: $0.updated) },
            companies: store.companies.map { .init(id: $0.id, name: String($0.name.prefix(180))) }, connectionReady: store.connectionReady,
            screenAllowed: MacDesktop.canSee && !screenLocked, controlAllowed: MacDesktop.canControl && !screenLocked, canControlRemotely: allowControl,
            computerActive: store.computer.active, computerPaused: store.computer.paused, computerPhase: String(store.computer.phase.prefix(2000)), computerQuestion: String(store.computer.question.prefix(4000)), computerResult: String((store.computer.error.isEmpty ? store.computer.result : store.computer.error).prefix(8000)))
        snapshot.receipts = Array(ledger.receipts.suffix(80))
        try? await connection.send(.snapshot, snapshot)
        if let id = subscribed, let mission = state.missions.first(where: { $0.id == id }) {
            let conversation = RemoteConversation(id: id, messages: mission.messages.suffix(40).map { .init(id: $0.id, role: $0.role, text: String($0.text.suffix(16000))) }, error: mission.error)
            try? await connection.send(.conversation, conversation)
        }
    }
}
