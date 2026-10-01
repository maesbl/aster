import AppKit
import SwiftUI
import EventKit
import UserNotifications

@MainActor final class AsterStore: ObservableObject {
    @Published var state = SavedState()
    @Published var page = "Personajes"
    @Published var selectedMission: UUID?
    @Published var busy = false
    @Published var activity = ""
    @Published var notice = ""
    @Published var calendarStatus = "Sin conectar"
    @Published var mailStatus = "Sin conectar"
    @Published var connectionStatus = "Conexión configurada · límite de uso detectado"
    @Published var artifacts: [AgentArtifact] = []
    @Published var previewMood: AvatarMood = .calm
    private var task: Task<Void, Never>?
    private var activeMissionID: UUID?
    private var timer: Timer?
    private var parts: [String: String] = [:]
    private var partOrder: [String] = []
    private var calendar = EKEventStore()
    private let file: URL
    var onFloatingChange: (() -> Void)?
    var agent: Specialist { state.specialists.first { $0.id == state.preferences.selectedAgent } ?? state.specialists[0] }
    var mission: Mission? { state.missions.first { $0.id == selectedMission } }
    var unread: Int { state.inbox.filter { !$0.read }.count }
    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Aster")
        file = directory.appendingPathComponent("state.json")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: file.path) { state = try JSONDecoder().decode(SavedState.self, from: Data(contentsOf: file)) }
        } catch { notice = "No se han podido cargar los datos anteriores. Se conserva el archivo original: \(error.localizedDescription)" }
        for index in state.missions.indices where state.missions[index].status == "Trabajando" {
            state.missions[index].status = "Por recuperar"
            state.missions[index].error = "La app se cerró durante la misión. Recupera la sesión para ver su estado actual."
        }
        if state.preferences.watchCalendar { calendarStatus = EKEventStore.authorizationStatus(for: .event) == .fullAccess ? "Conectado" : "Permiso pendiente" }
        if state.preferences.watchMail { mailStatus = "Activado · pendiente de revisión" }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in Task { @MainActor in await self?.tick() } }
    }
    func save() {
        do { try JSONEncoder().encode(state).write(to: file, options: [.atomic]); onFloatingChange?() }
        catch { notice = "No se han podido guardar los cambios: \(error.localizedDescription)" }
    }
    func select(_ id: String) { state.preferences.selectedAgent = id; save() }
    func updateAgent(_ agent: Specialist) { if let index = state.specialists.firstIndex(where: { $0.id == agent.id }) { state.specialists[index] = agent; save() } }
    func createCompany(name: String, goal: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines), goal = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !goal.isEmpty else { return }
        state.companies.append(.init(name: name, goal: goal)); save()
    }
    func run(_ text: String, companyID: UUID? = nil, fresh: Bool = false, proactive: Bool = false) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !busy else { return }
        let specialist = agent
        var index: Int
        if !fresh, let selectedMission, let current = state.missions.firstIndex(where: { $0.id == selectedMission }) {
            index = current
            // A failed or interrupted turn must be reconciled before accepting another input.
            guard !["Por recuperar", "Cancelación pendiente"].contains(state.missions[index].status) else { notice = "Recupera esta sesión antes de enviar otra instrucción."; return }
        } else {
            state.missions.insert(.init(title: String(text.prefix(70)), specialistID: specialist.id, companyID: companyID), at: 0)
            index = 0; selectedMission = state.missions[0].id
        }
        let id = state.missions[index].id
        let sessionID = state.missions[index].sessionID
        let usedAgent = state.specialists.first { $0.id == state.missions[index].specialistID } ?? specialist
        let company = state.companies.first { $0.id == (companyID ?? state.missions[index].companyID) }
        let input = company.map { "Empresa: \($0.name)\nObjetivo: \($0.goal)\nNotas: \($0.notes)\n\nInstrucción: \(text)" } ?? text
        state.missions[index].messages.append(.init(role: "user", text: text))
        state.missions[index].messages.append(.init(role: "assistant", text: ""))
        state.missions[index].status = "Trabajando"; state.missions[index].error = nil; state.missions[index].turnID = nil
        state.missions[index].updated = Date(); busy = true; activity = "Preparando la sesión"; parts = [:]; partOrder = []
        page = "Misiones"; activeMissionID = id; artifacts = []; save()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let api = try AgentAPI()
                try await api.run(sessionID: sessionID, specialist: usedAgent, input: input) { [weak self] event in self?.handle(event, id: id) }
                if let mission = self.state.missions.first(where: { $0.id == id }), let sid = mission.sessionID, mission.messages.last?.text.isEmpty == true {
                    let (_, text, _) = try await api.recover(sid, turnID: mission.turnID)
                    if let i = self.state.missions.firstIndex(where: { $0.id == id }), let last = self.state.missions[i].messages.lastIndex(where: { $0.role == "assistant" }) { self.state.missions[i].messages[last].text = text }
                }
                self.setStatus(id, "Completada")
                self.connectionStatus = "Conectado a OpenAI"
                if let mission = self.state.missions.first(where: { $0.id == id }), let sid = mission.sessionID {
                    do { self.artifacts = try await api.artifacts(sid, turnID: mission.turnID) }
                    catch { self.notice = "La misión terminó, pero no se pudo cargar su lista de archivos: \(error.localizedDescription)" }
                }
                if proactive, let mission = self.state.missions.first(where: { $0.id == id }) {
                    self.addNote(title: "\(usedAgent.name) ha preparado una propuesta", text: String((mission.messages.last?.text ?? "Abre la misión para revisar el resultado.").prefix(400)), fingerprint: id.uuidString, missionID: id)
                }
            } catch is CancellationError {
                self.setStatus(id, "Por recuperar", error: "Comprueba el estado de la sesión para confirmar la cancelación.")
            } catch {
                let message = error.localizedDescription
                self.setStatus(id, "Por recuperar", error: message)
                if message.contains("facturación") || message.contains("límite de uso") {
                    self.connectionStatus = "Límite de uso · revisa la facturación"
                    self.state.preferences.autonomous = false
                }
                if proactive { self.addNote(title: "La misión necesita atención", text: message, fingerprint: "failure-" + id.uuidString, missionID: id) }
            }
            self.busy = false; self.activeMissionID = nil; self.activity = ""; self.save(); self.task = nil
        }
    }
    private func handle(_ event: AgentEvent, id: UUID) {
        guard let index = state.missions.firstIndex(where: { $0.id == id }) else { return }
        switch event {
        case .session(let session): state.missions[index].sessionID = session; save()
        case .turn(let turn): state.missions[index].turnID = turn; activity = "El agente está trabajando"; save()
        case .text(let item, let text, let complete):
            if parts[item] == nil { partOrder.append(item) }
            parts[item] = complete ? text : (parts[item] ?? "") + text
            if !state.missions[index].messages.isEmpty { state.missions[index].messages[state.missions[index].messages.count - 1].text = partOrder.compactMap { parts[$0] }.joined(separator: "\n\n") }
        case .activity(let message): activity = message
        default: break
        }
    }
    private func setStatus(_ id: UUID, _ status: String, error: String? = nil) {
        if let index = state.missions.firstIndex(where: { $0.id == id }) { state.missions[index].status = status; state.missions[index].error = error }
    }
    func stop() {
        guard let mission = state.missions.first(where: { $0.id == activeMissionID }), busy else { return }
        guard let sid = mission.sessionID else { notice = "La sesión aún se está creando. Espera a que aparezca para poder cancelarla sin dejar trabajo remoto."; return }
        Task {
            do { try await AgentAPI().cancel(sid); task?.cancel(); setStatus(mission.id, "Cancelación pendiente"); activity = "Confirmando la cancelación"; save() }
            catch { notice = "No se ha confirmado la cancelación: \(error.localizedDescription). La sesión podría seguir trabajando." }
        }
    }
    func recover() {
        guard let mission, let sid = mission.sessionID, !busy else { notice = "No hay una sesión guardada para recuperar."; return }
        busy = true; activity = "Recuperando el trabajo guardado"
        task = Task {
            do {
                let (status, text, error) = try await AgentAPI().recover(sid, turnID: mission.turnID)
                if let index = state.missions.firstIndex(where: { $0.id == mission.id }) {
                    if !text.isEmpty, let last = state.missions[index].messages.lastIndex(where: { $0.role == "assistant" }) { state.missions[index].messages[last].text = text }
                    state.missions[index].status = ["completed": "Completada", "failed": "Fallida", "cancelled": "Cancelada"][status] ?? "Por recuperar"
                    state.missions[index].error = error ?? (["completed", "failed", "cancelled"].contains(status) ? nil : "La sesión sigue trabajando. Vuelve a recuperar en unos momentos.")
                }
            } catch { notice = error.localizedDescription }
            busy = false; activity = ""; task = nil; save()
        }
    }
    func exportMission() {
        guard let mission else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = "\(mission.title.prefix(40)).md"; panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            let text = "# \(mission.title)\n\n" + mission.messages.filter { !$0.text.isEmpty }.map { "## \($0.role == "user" ? "Tú" : "Aster")\n\n\($0.text)" }.joined(separator: "\n\n")
            do { try text.write(to: url, atomically: true, encoding: .utf8); notice = "Misión exportada." } catch { notice = error.localizedDescription }
        }
    }
    func loadArtifacts() {
        guard let mission, let sid = mission.sessionID else { return }
        let intended = mission.id
        Task {
            do { let result = try await AgentAPI().artifacts(sid, turnID: mission.turnID); if selectedMission == intended { artifacts = result } }
            catch { notice = error.localizedDescription }
        }
    }
    func downloadArtifact(_ artifact: AgentArtifact) {
        guard let mission, let sid = mission.sessionID else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = URL(fileURLWithPath: artifact.path).lastPathComponent
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                do { try await AgentAPI().download(artifact, sessionID: sid, destination: url); notice = "Archivo descargado: \(url.lastPathComponent)" }
                catch { notice = error.localizedDescription }
            }
        }
    }
    func addNote(title: String, text: String, fingerprint: String, missionID: UUID? = nil) {
        guard !state.inbox.contains(where: { $0.fingerprint == fingerprint }) else { return }
        state.inbox.insert(.init(title: title, text: text, fingerprint: fingerprint, missionID: missionID), at: 0)
        save()
        if state.preferences.notifications {
            let content = UNMutableNotificationContent(); content.title = title; content.body = text; content.sound = .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: fingerprint, content: content, trigger: nil))
        }
    }
    func markRead(_ id: UUID) { if let i = state.inbox.firstIndex(where: { $0.id == id }) { state.inbox[i].read = true; save() } }
    func requestNotifications() {
        Task {
            do { state.preferences.notifications = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]); save() }
            catch { notice = error.localizedDescription }
        }
    }
    func connectCalendar() {
        Task {
            do {
                state.preferences.watchCalendar = try await calendar.requestFullAccessToEvents()
                calendarStatus = state.preferences.watchCalendar ? "Conectado" : "Permiso denegado"; save()
                if state.preferences.watchCalendar { await scan(manual: true) }
            } catch { calendarStatus = error.localizedDescription }
        }
    }
    func connectMail() {
        Task {
            mailStatus = "Solicitando acceso a Apple Mail"
            do {
                let text = try await Self.readMail()
                state.preferences.watchMail = true; mailStatus = "Conectado"; save(); ingestMail(text)
            } catch { state.preferences.watchMail = false; mailStatus = error.localizedDescription; save() }
        }
    }
    nonisolated static func readMail() async throws -> String {
        try await Task.detached(priority: .utility) {
            let source = """
            tell application "Mail"
                set unseen to (messages of inbox whose read status is false)
                set resultText to ""
                set limitCount to count of unseen
                if limitCount > 10 then set limitCount to 10
                repeat with n from 1 to limitCount
                    set m to item n of unseen
                    set resultText to resultText & (id of m as text) & "||" & (sender of m as text) & "||" & (subject of m as text) & linefeed
                end repeat
                return resultText
            end tell
            """
            var error: NSDictionary?
            guard let script = NSAppleScript(source: source) else { throw AsterError.message("No se ha podido preparar la conexión con Apple Mail.") }
            let result = script.executeAndReturnError(&error)
            if error != nil { throw AsterError.message("Apple Mail no ha permitido la lectura. Activa el acceso en Ajustes del Sistema → Privacidad y seguridad → Automatización.") }
            return result.stringValue ?? ""
        }.value
    }
    private func ingestMail(_ text: String) {
        for line in text.split(separator: "\n") {
            let pieces = line.components(separatedBy: "||")
            if pieces.count >= 3 { addNote(title: "Correo sin leer", text: pieces[1] + "\n" + pieces.dropFirst(2).joined(separator: "||"), fingerprint: "mail-" + pieces[0]) }
        }
    }
    func scan(manual: Bool = true) async {
        if state.preferences.watchCalendar && EKEventStore.authorizationStatus(for: .event) == .fullAccess {
            let now = Date(), end = now.addingTimeInterval(manual ? 86400 : 1800)
            let predicate = calendar.predicateForEvents(withStart: now, end: end, calendars: nil)
            for event in calendar.events(matching: predicate).sorted(by: { $0.startDate < $1.startDate }) where event.startDate >= now {
                let time = event.startDate.formatted(date: .abbreviated, time: .shortened)
                addNote(title: manual ? "En tu agenda" : "Una cita empieza pronto", text: "\(event.title ?? "Evento") · \(time)", fingerprint: "calendar-\(event.calendarItemIdentifier)-\(event.startDate.timeIntervalSince1970)")
            }
            calendarStatus = "Conectado · revisión \(Date().formatted(date: .omitted, time: .shortened))"
        }
        if state.preferences.watchMail {
            do { ingestMail(try await Self.readMail()); mailStatus = "Conectado · revisión \(Date().formatted(date: .omitted, time: .shortened))" }
            catch { mailStatus = error.localizedDescription }
        }
        state.preferences.lastWatch = Date(); save()
        if manual { notice = "Revisión terminada. Las novedades aparecen en la bandeja." }
    }
    private func tick() async {
        let now = Date()
        if state.preferences.watchCalendar || state.preferences.watchMail {
            if now.timeIntervalSince(state.preferences.lastWatch ?? .distantPast) > 900 { await scan(manual: false) }
        }
        guard state.preferences.autonomous, !busy, let company = state.companies.first else { return }
        let day = now.formatted(.iso8601.year().month().day())
        if state.preferences.dayStamp != day { state.preferences.dayStamp = day; state.preferences.dailyRuns = 0 }
        guard state.preferences.dailyRuns < state.preferences.dailyLimit,
              now.timeIntervalSince(state.preferences.lastAutonomous ?? .distantPast) >= Double(state.preferences.intervalHours) * 3600 else { return }
        state.preferences.lastAutonomous = now; state.preferences.dailyRuns += 1; state.preferences.selectedAgent = "director"; save()
        run("Revisa nuestro objetivo y el trabajo anterior. Investiga si es necesario y prepara una propuesta concreta que haga avanzar la empresa. Evita repetir resultados ya preparados. Trabajo anterior:\n" + state.missions.filter { $0.companyID == company.id }.prefix(3).flatMap { $0.messages.filter { $0.role == "assistant" }.map(\.text) }.joined(separator: "\n").suffix(16000), companyID: company.id, fresh: true, proactive: true)
    }
}
