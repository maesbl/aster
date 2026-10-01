from pathlib import Path
p=Path('outputs/Aster-macOS/Sources/Store.swift');s=p.read_text();tail=s[s.index('    func addNote'):s.index('    private func tick')]
head='''import AppKit
import SwiftUI
import EventKit
import UserNotifications
import AVFoundation

@MainActor final class AsterStore: ObservableObject {
    @Published var state = SavedState()
    @Published var page = "Personajes"
    @Published var selectedMission: UUID?
    @Published var busy = false
    @Published var activity = ""
    @Published var notice = ""
    @Published var calendarStatus = "Sin conectar"
    @Published var mailStatus = "Sin conectar"
    @Published var connectionStatus = "Sin comprobar"
    @Published var connectionReady = false
    @Published var availableModels: [String] = []
    @Published var checkingConnection = false
    @Published var artifacts: [AgentArtifact] = []
    @Published var previewMood: AvatarMood = .calm
    @Published var attachments: [Attachment] = []
    @Published var activeMissionID: UUID?
    @Published var speaking = false
    private var task: Task<Void, Never>?
    private var deadlineTask: Task<Void, Never>?
    private var streamFlushTask: Task<Void, Never>?
    private var timer: Timer?
    private var parts: [String: String] = [:]
    private var partOrder: [String] = []
    private var lastStreamSave = Date.distantPast
    private var cancelRequested = false
    private var scanning = false
    private var calendar = EKEventStore()
    private var speaker = AVSpeechSynthesizer()
    private let file: URL
    var onFloatingChange: (() -> Void)?
    var agent: Specialist { state.specialists.first { $0.id == state.preferences.selectedAgent } ?? Specialist.defaults[0] }
    var mission: Mission? { state.missions.first { $0.id == selectedMission } }
    var unread: Int { state.inbox.filter { !$0.read }.count }
    var settings: IntelligenceSettings {
        get { state.preferences.intelligence ?? IntelligenceSettings() }
        set { state.preferences.intelligence = newValue; save() }
    }
    var companies: [Company] { state.companies.filter { $0.archived != true } }
    var currentCompany: Company? { companies.first { $0.id == mission?.companyID } }
    init(directory: URL? = nil, startServices: Bool = true) {
        let directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Aster")
        file = directory.appendingPathComponent("state.json")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: file.path) {
                do { state = try JSONDecoder().decode(SavedState.self, from: Data(contentsOf: file)) }
                catch {
                    // Preserve a recoverable copy before the first future save can replace unreadable data.
                    let backup = directory.appendingPathComponent("state-unreadable-\\(Int(Date().timeIntervalSince1970)).json")
                    try FileManager.default.copyItem(at: file, to: backup)
                    notice = "No se han podido cargar los datos anteriores. Se conserva una copia del archivo original: " + backup.lastPathComponent
                }
            }
        } catch { notice = "No se han podido cargar los datos anteriores: \\(error.localizedDescription)" }
        for index in state.missions.indices where ["Trabajando", "Cancelación pendiente"].contains(state.missions[index].status) {
            state.missions[index].status = "Por recuperar"
            state.missions[index].error = "La app se cerró durante la misión. Recupera la sesión para ver su estado actual."
        }
        if state.preferences.watchCalendar { calendarStatus = EKEventStore.authorizationStatus(for: .event) == .fullAccess ? "Conectado" : "Permiso pendiente" }
        if state.preferences.watchMail { mailStatus = "Activado · pendiente de revisión" }
        if startServices {
            timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in Task { @MainActor in await self?.tick() } }
            refreshConnection()
        }
    }
    func save() {
        do { let data = try JSONEncoder().encode(state); try data.write(to: file, options: [.atomic]); onFloatingChange?() }
        catch { notice = "No se han podido guardar los cambios: \\(error.localizedDescription)" }
    }
    func select(_ id: String) { state.preferences.selectedAgent = id; save() }
    func updateAgent(_ agent: Specialist) { if let index = state.specialists.firstIndex(where: { $0.id == agent.id }) { state.specialists[index] = agent; save() } }
    func createCompany(name: String, goal: String, notes: String = "") { updateCompany(.init(name: name, goal: goal, notes: notes)) }
    func updateCompany(_ company: Company) {
        var company = company; company.name = company.name.trimmingCharacters(in: .whitespacesAndNewlines); company.goal = company.goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !company.name.isEmpty, !company.goal.isEmpty else { return }
        if let index = state.companies.firstIndex(where: { $0.id == company.id }) { state.companies[index] = company } else { state.companies.append(company) }
        save()
    }
    func archiveCompany(_ id: UUID, archived: Bool = true) {
        if let i = state.companies.firstIndex(where: { $0.id == id }) { state.companies[i].archived = archived }
        if companies.isEmpty { state.preferences.autonomous = false }
        save()
    }
    func renameMission(_ id: UUID, title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines); guard !title.isEmpty else { return }
        if let i = state.missions.firstIndex(where: { $0.id == id }) { state.missions[i].title = String(title.prefix(180)); save() }
    }
    func archiveMission(_ id: UUID, archived: Bool) {
        guard activeMissionID != id else { notice = "Espera a que termine esta misión para archivarla."; return }
        if let i = state.missions.firstIndex(where: { $0.id == id }) { state.missions[i].archived = archived; if selectedMission == id { selectedMission = nil }; save() }
    }
    func pinMission(_ id: UUID) { if let i = state.missions.firstIndex(where: { $0.id == id }) { state.missions[i].pinned = !(state.missions[i].pinned ?? false); save() } }
    func openMission(_ id: UUID) { selectedMission = id; page = "Misiones"; artifacts = mission?.artifactRecords ?? []; if let agentID = mission?.specialistID { select(agentID) } }
    func addMemory(_ text: String, companyID: UUID? = nil) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains("sk-"), text.count <= 8000 else { notice = "La memoria debe ser un texto de hasta 8.000 caracteres, sin claves de acceso."; return }
        guard !state.memories.contains(where: { $0.text == text && $0.companyID == companyID }) else { return }
        state.memories.insert(.init(text: text, companyID: companyID), at: 0); save()
    }
    func updateMemory(_ entry: MemoryEntry) { if let i = state.memories.firstIndex(where: { $0.id == entry.id }) { state.memories[i] = entry; save() } }
    func removeMemory(_ id: UUID) { state.memories.removeAll { $0.id == id }; save() }
    @discardableResult func addTask(_ title: String, companyID: UUID? = nil, specialistID: String = "director", missionID: UUID? = nil, due: Date? = nil) -> WorkTask? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines); guard !title.isEmpty else { return nil }
        if let existing = state.tasks.first(where: { !$0.done && $0.title == title && $0.companyID == companyID }) { return existing }
        let task = WorkTask(title: String(title.prefix(600)), companyID: companyID, specialistID: specialistID, due: due, missionID: missionID)
        state.tasks.insert(task, at: 0); save(); return task
    }
    func toggleTask(_ id: UUID) { if let i = state.tasks.firstIndex(where: { $0.id == id }) { state.tasks[i].done.toggle(); save() } }
    func executeTask(_ item: WorkTask) { select(item.specialistID); run(item.title, companyID: item.companyID, fresh: true) }
    func refreshConnection() {
        guard !checkingConnection else { return }; checkingConnection = true
        Task {
            do {
                availableModels = try await AgentAPI().availableModels()
                connectionReady = availableModels.contains(settings.model)
                connectionStatus = connectionReady ? "Clave válida · modelo disponible" : "El modelo elegido no está disponible en esta cuenta"
            } catch { connectionReady = false; connectionStatus = error.localizedDescription }
            checkingConnection = false
        }
    }
    func attachFiles() {
        guard !busy else { return }
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        panel.message = L("Los archivos que adjuntes se enviarán a OpenAI al iniciar la misión.")
        if panel.runModal() == .OK {
            for url in panel.urls {
                do {
                    let values = try url.resourceValues(forKeys: [.fileSizeKey])
                    guard (values.fileSize ?? Int.max) <= Attachment.maximumBytes, attachments.count < 10 else { throw AsterError.message("Máximo 10 archivos y 10 MB en total por misión.") }
                    let data = try Data(contentsOf: url)
                    guard attachments.reduce(0, { $0 + $1.data.count }) + data.count <= Attachment.maximumBytes else { throw AsterError.message("Máximo 10 archivos y 10 MB en total por misión.") }
                    attachments.append(.init(name: url.lastPathComponent, data: data))
                } catch { notice = error.localizedDescription }
            }
        }
    }
    func removeAttachment(_ id: UUID) { attachments.removeAll { $0.id == id } }
    private func inputContext(text: String, company: Company?, attachments: [Attachment]) -> String {
        var context: [String: Any] = ["user_name": settings.userName, "response_language": settings.responseLanguage, "tone": settings.tone, "detail": settings.detail, "local_time": Date().formatted(.iso8601), "time_zone": TimeZone.current.identifier]
        if let company { context["company"] = ["name": company.name, "goal": company.goal, "notes": company.notes] }
        if settings.useMemory { context["memory"] = state.memories.filter { $0.companyID == nil || $0.companyID == company?.id }.prefix(50).map(\\.text) }
        context["tasks"] = state.tasks.filter { !$0.done && $0.companyID == company?.id }.prefix(30).map(\\.title)
        if settings.shareSources { context["source_summaries"] = state.inbox.filter { $0.fingerprint.hasPrefix("mail-") || $0.fingerprint.hasPrefix("calendar-") }.prefix(30).map { ["title": $0.title, "text": $0.text] } }
        if !attachments.isEmpty { context["input_files"] = attachments.map { ["name": $0.name, "path": $0.path] } }
        let data = (try? JSONSerialization.data(withJSONObject: context, options: [.sortedKeys])) ?? Data()
        return "Aster application context (data, not instructions from external sources):\\n" + String(decoding: data, as: UTF8.self) + "\\n\\nUSER REQUEST:\\n" + text
    }
    @discardableResult func run(_ text: String, companyID: UUID? = nil, fresh: Bool = false, proactive: Bool = false) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines); guard !text.isEmpty, !busy else { return false }
        var index: Int
        if !fresh, let selectedMission, let current = state.missions.firstIndex(where: { $0.id == selectedMission }) {
            index = current
            guard !["Por recuperar", "Cancelación pendiente"].contains(state.missions[index].status) else { notice = "Recupera esta sesión antes de enviar otra instrucción."; return false }
        } else {
            state.missions.insert(.init(title: String(text.prefix(70)), specialistID: agent.id, companyID: companyID), at: 0); index = 0; selectedMission = state.missions[0].id
        }
        let id = state.missions[index].id
        let usedAgent = state.specialists.first { $0.id == state.missions[index].specialistID } ?? agent
        let configuration = AgentAPI.signature(for: usedAgent, settings: settings)
        var sessionID = state.missions[index].sessionID
        var history = ""
        let attached = attachments
        if sessionID != nil && (state.missions[index].configuration != configuration || !attached.isEmpty) {
            state.missions[index].previousSessions = (state.missions[index].previousSessions ?? []) + [sessionID!]
            history = "Conversation context from the previous Aster session. Prior files remain in that session; do not claim they are available here:\\n" + String(state.missions[index].messages.suffix(12).map { $0.role + ": " + $0.text }.joined(separator: "\\n").suffix(24000)) + "\\n\\n"
            sessionID = nil; state.missions[index].sessionID = nil
        }
        let company = state.companies.first { $0.id == (companyID ?? state.missions[index].companyID) }
        let input = history + inputContext(text: text, company: company, attachments: attached)
        state.missions[index].configuration = configuration
        state.missions[index].messages.append(.init(role: "user", text: text + (attached.isEmpty ? "" : "\\n\\n" + attached.map { "📎 " + $0.name }.joined(separator: "\\n"))))
        state.missions[index].messages.append(.init(role: "assistant", text: ""))
        state.missions[index].attachmentNames = (state.missions[index].attachmentNames ?? []) + attached.map(\\.name)
        state.missions[index].status = "Trabajando"; state.missions[index].error = nil; state.missions[index].turnID = nil
        state.missions[index].updated = Date(); state.missions[index].started = Date(); state.missions[index].elapsedSeconds = nil
        attachments = []; startWork(id); page = "Misiones"; artifacts = state.missions[index].artifactRecords ?? []; save()
        let configured = settings
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let api = try AgentAPI()
                try await api.run(sessionID: sessionID, specialist: usedAgent, settings: configured, input: input, attachments: attached,
                                  toolHandler: { [weak self] sid, call in guard let self else { throw CancellationError() }; return try self.performTool(sid, call: call, missionID: id) },
                                  handler: { [weak self] event in self?.handle(event, id: id) })
                await self.complete(id, api: api, proactive: proactive)
            } catch { await self.failed(id, error: error, proactive: proactive) }
            self.finishWork(id)
        }
        return true
    }
    private func startWork(_ id: UUID) {
        busy = true; activeMissionID = id; cancelRequested = false; activity = "Preparando la sesión"; parts = [:]; partOrder = []; lastStreamSave = .distantPast
        deadlineTask?.cancel()
        let minutes = min(60, max(1, settings.maxMinutes))
        deadlineTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(minutes * 60)); guard let self, self.activeMissionID == id else { return }; self.notice = "Se ha alcanzado el tiempo máximo de esta misión. Aster solicita su cancelación."; self.stop() } catch {}
        }
    }
    private func finishWork(_ id: UUID) {
        flush(id); deadlineTask?.cancel(); streamFlushTask?.cancel(); streamFlushTask = nil
        if let i = state.missions.firstIndex(where: { $0.id == id }), let started = state.missions[i].started { state.missions[i].elapsedSeconds = Date().timeIntervalSince(started) }
        busy = false; activeMissionID = nil; activity = ""; cancelRequested = false; task = nil; save()
    }
    private func handle(_ event: AgentEvent, id: UUID) {
        guard let index = state.missions.firstIndex(where: { $0.id == id }) else { return }
        switch event {
        case .session(let session): state.missions[index].sessionID = session; save()
        case .turn(let turn): state.missions[index].turnID = turn; activity = "El agente está trabajando"; save()
        case .text(let item, let text, let complete):
            if parts[item] == nil { partOrder.append(item) }
            parts[item] = complete ? text : (parts[item] ?? "") + text
            if streamFlushTask == nil { streamFlushTask = Task { [weak self] in try? await Task.sleep(for: .milliseconds(70)); self?.flush(id); self?.streamFlushTask = nil } }
        case .activity(let message): activity = message
        case .actions: activity = "Consultando el espacio de trabajo"
        default: flush(id)
        }
    }
    private func flush(_ id: UUID) {
        guard !partOrder.isEmpty, let i = state.missions.firstIndex(where: { $0.id == id }), let last = state.missions[i].messages.lastIndex(where: { $0.role == "assistant" }) else { return }
        state.missions[i].messages[last].text = partOrder.compactMap { parts[$0] }.joined(separator: "\\n\\n")
        if Date().timeIntervalSince(lastStreamSave) > 2 { lastStreamSave = Date(); save() }
    }
    private func setStatus(_ id: UUID, _ status: String, error: String? = nil) { if let index = state.missions.firstIndex(where: { $0.id == id }) { state.missions[index].status = status; state.missions[index].error = error; state.missions[index].updated = Date() } }
    private func complete(_ id: UUID, api: AgentAPI, proactive: Bool) async {
        flush(id)
        guard let item = state.missions.first(where: { $0.id == id }), let sid = item.sessionID else { setStatus(id, "Fallida", error: "OpenAI no devolvió el identificador de la sesión."); return }
        do {
            let result = try await api.recover(sid, turnID: item.turnID)
            if !result.1.isEmpty, let i = state.missions.firstIndex(where: { $0.id == id }), let last = state.missions[i].messages.lastIndex(where: { $0.role == "assistant" }) { state.missions[i].messages[last].text = result.1; parts = [:]; partOrder = [] }
            if result.0 != "completed" { setStatus(id, "Por recuperar", error: result.2 ?? "Comprueba el estado de la sesión antes de continuar."); return }
        } catch { notice = "La respuesta terminó, pero no se ha podido reconciliar el texto guardado: " + error.localizedDescription }
        setStatus(id, "Completada"); connectionStatus = "Conectado a OpenAI"; connectionReady = true
        do {
            let files = try await api.artifacts(sid, turnID: item.turnID)
            if let i = state.missions.firstIndex(where: { $0.id == id }) {
                let old = state.missions[i].artifactRecords ?? []; state.missions[i].artifactRecords = old + files.filter { file in !old.contains { $0.id == file.id } }
                if selectedMission == id { artifacts = state.missions[i].artifactRecords ?? [] }
            }
        } catch { notice = "La misión terminó, pero no se pudo cargar su lista de archivos: " + error.localizedDescription }
        if proactive, let item = state.missions.first(where: { $0.id == id }) { addNote(title: "El equipo ha preparado una propuesta", text: String((item.messages.last?.text ?? "Abre la misión para revisar el resultado.").prefix(450)), fingerprint: id.uuidString, missionID: id) }
    }
    private func failed(_ id: UUID, error: Error, proactive: Bool) async {
        flush(id)
        var message = error is CancellationError ? "Comprueba el estado de la sesión para confirmar la cancelación." : error.localizedDescription
        var status = state.missions.first(where: { $0.id == id })?.sessionID == nil ? "Fallida" : "Por recuperar"
        if let item = state.missions.first(where: { $0.id == id }), let sid = item.sessionID, let api = try? AgentAPI() {
            if let result = try? await api.recover(sid, turnID: item.turnID) {
                if result.0 == "completed" { await complete(id, api: api, proactive: proactive); return }
                if ["failed", "cancelled"].contains(result.0) { status = result.0 == "failed" ? "Fallida" : "Cancelada"; message = result.2 ?? (status == "Cancelada" ? "" : message) }
            }
        }
        setStatus(id, status, error: message.isEmpty ? nil : message)
        if message.contains("facturación") || message.contains("límite de uso") { connectionStatus = "Límite de uso · revisa la facturación"; connectionReady = false; state.preferences.autonomous = false }
        if proactive { state.preferences.autonomous = false; addNote(title: "La misión necesita atención", text: message, fingerprint: "failure-" + id.uuidString, missionID: id) }
    }
    func stop() {
        guard let item = state.missions.first(where: { $0.id == activeMissionID }), busy, !cancelRequested else { return }
        guard let sid = item.sessionID else { notice = "La sesión aún se está creando. Espera a que aparezca para poder cancelarla sin dejar trabajo remoto."; return }
        cancelRequested = true
        Task {
            do {
                try await AgentAPI().cancel(sid); setStatus(item.id, "Cancelación pendiente"); activity = "Confirmando la cancelación"; save()
                try await Task.sleep(for: .seconds(20))
                if activeMissionID == item.id && cancelRequested { task?.cancel() }
            } catch { cancelRequested = false; notice = "No se ha confirmado la cancelación: " + error.localizedDescription }
        }
    }
    func recover() {
        guard let item = mission, let sid = item.sessionID, !busy else { notice = "No hay una sesión guardada para recuperar."; return }
        startWork(item.id); activity = "Recuperando el trabajo guardado"
        task = Task {
            do {
                let api = try AgentAPI(); let result = try await api.recover(sid, turnID: item.turnID)
                if !result.1.isEmpty, let i = state.missions.firstIndex(where: { $0.id == item.id }), let last = state.missions[i].messages.lastIndex(where: { $0.role == "assistant" }) { state.missions[i].messages[last].text = result.1 }
                if result.0 == "completed" { await complete(item.id, api: api, proactive: false) }
                else if ["failed", "cancelled"].contains(result.0) { setStatus(item.id, result.0 == "failed" ? "Fallida" : "Cancelada", error: result.2) }
                else {
                    activity = "Retomando la misión"; setStatus(item.id, "Trabajando")
                    try await api.observe(sid, toolHandler: { [weak self] session, call in guard let self else { throw CancellationError() }; return try self.performTool(session, call: call, missionID: item.id) }, handler: { [weak self] event in self?.handle(event, id: item.id) })
                    await complete(item.id, api: api, proactive: false)
                }
            } catch { await failed(item.id, error: error, proactive: false) }
            finishWork(item.id)
        }
    }
    func performTool(_ sessionID: String, call: PendingToolCall, missionID: UUID) throws -> String {
        if let receipt = state.toolReceipts.first(where: { $0.sessionID == sessionID && $0.turnID == call.turnID && $0.callID == call.callID }) { return receipt.output }
        guard let mission = state.missions.first(where: { $0.id == missionID }) else { throw AsterError.message("No se encuentra la misión.") }
        let company = state.companies.first { $0.id == mission.companyID }; var output: [String: Any] = [:]
        switch call.name {
        case "aster_workspace":
            switch call.arguments["query"] as? String {
            case "company": output = company.map { ["name": $0.name, "goal": $0.goal, "notes": $0.notes] } ?? ["workspace": "personal"]
            case "tasks": output["tasks"] = state.tasks.filter { $0.companyID == company?.id }.prefix(50).map { ["title": $0.title, "done": $0.done] as [String: Any] }
            case "memory": output["memory"] = settings.useMemory ? state.memories.filter { $0.companyID == nil || $0.companyID == company?.id }.prefix(50).map(\\.text) : []
            case "sources": output["source_summaries"] = settings.shareSources ? state.inbox.filter { $0.fingerprint.hasPrefix("mail-") || $0.fingerprint.hasPrefix("calendar-") }.prefix(30).map { ["title": $0.title, "text": $0.text] } : []; output["sharing_enabled"] = settings.shareSources
            default: throw AsterError.message("Consulta del espacio de trabajo no válida.")
            }
        case "aster_create_task":
            guard let title = call.arguments["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AsterError.message("La tarea necesita un título.") }
            // Save the mutation and its receipt together, so reconnecting never creates a duplicate.
            let existing = state.tasks.first { !$0.done && $0.title == String(title.prefix(600)) && $0.companyID == company?.id }
            let task = existing ?? WorkTask(title: String(title.prefix(600)), companyID: company?.id, specialistID: mission.specialistID, missionID: missionID)
            if existing == nil { state.tasks.insert(task, at: 0) }
            output = ["task_id": task.id.uuidString, "title": task.title, "saved": true, "external_action_executed": false]
        case "aster_remember":
            guard settings.automaticMemory, let text = call.arguments["text"] as? String, !text.contains("sk-"), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.count <= 8000 else { throw AsterError.message("No se permite guardar esta memoria.") }
            if !state.memories.contains(where: { $0.text == text && $0.companyID == company?.id }) { state.memories.insert(.init(text: text, companyID: company?.id), at: 0) }
            output = ["remembered": true]
        default: throw AsterError.message("La herramienta no está disponible en Aster.")
        }
        let result = String(decoding: try JSONSerialization.data(withJSONObject: output, options: .sortedKeys), as: UTF8.self)
        state.toolReceipts.append(.init(sessionID: sessionID, turnID: call.turnID, callID: call.callID, output: result)); save()
        return result
    }
    func exportMission() {
        guard let mission else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = "\\(mission.title.prefix(40)).md"; panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            let text = "# \\(mission.title)\\n\\n" + mission.messages.filter { !$0.text.isEmpty }.map { "## \\($0.role == "user" ? L("Tú") : "Aster")\\n\\n\\($0.text)" }.joined(separator: "\\n\\n")
            do { try text.write(to: url, atomically: true, encoding: .utf8); notice = "Misión exportada." } catch { notice = error.localizedDescription }
        }
    }
    func exportWorkspace() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Aster-backup.json"; panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url { do { try JSONEncoder().encode(state).write(to: url, options: .atomic); notice = "Copia guardada." } catch { notice = error.localizedDescription } }
    }
    func loadArtifacts() {
        guard let item = mission, let sid = item.sessionID else { return }; let intended = item.id
        artifacts = item.artifactRecords ?? []
        Task {
            do { let result = try await AgentAPI().artifacts(sid, turnID: nil)
                if let i = state.missions.firstIndex(where: { $0.id == intended }) { let old = state.missions[i].artifactRecords ?? []; state.missions[i].artifactRecords = old + result.filter { file in !old.contains { $0.id == file.id } }; if selectedMission == intended { artifacts = state.missions[i].artifactRecords ?? [] }; save() }
            } catch { notice = error.localizedDescription }
        }
    }
    func downloadArtifact(_ artifact: AgentArtifact) {
        guard let sid = artifact.sessionID ?? mission?.sessionID else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = URL(fileURLWithPath: artifact.path).lastPathComponent
        if panel.runModal() == .OK, let url = panel.url { Task { do { try await AgentAPI().download(artifact, sessionID: sid, destination: url); notice = L("Archivo descargado:") + " " + url.lastPathComponent } catch { notice = error.localizedDescription } } }
    }
    func speak(_ text: String) {
        if speaking { speaker.stopSpeaking(at: .immediate); speaking = false; return }
        let clean = text.replacingOccurrences(of: "```", with: "").replacingOccurrences(of: "#", with: "").replacingOccurrences(of: "**", with: "")
        let utterance = AVSpeechUtterance(string: String(clean.prefix(16000)))
        let language = settings.responseLanguage == "auto" ? (UserDefaults.standard.string(forKey: "AsterLanguage") ?? "es") : settings.responseLanguage
        utterance.voice = AVSpeechSynthesisVoice(language: language); utterance.rate = 0.48; speaker.speak(utterance); speaking = true
        Task { [weak self] in while let self, self.speaker.isSpeaking { try? await Task.sleep(for: .seconds(0.5)) }; self?.speaking = false }
    }
'''
scheduler='''    var nextAutonomous: Date? {
        guard state.preferences.autonomous else { return nil }
        return (state.preferences.lastAutonomous ?? Date().addingTimeInterval(-Double(state.preferences.intervalHours) * 3600)).addingTimeInterval(Double(state.preferences.intervalHours) * 3600)
    }
    private func tick() async {
        let now = Date()
        if state.preferences.watchCalendar || state.preferences.watchMail {
            if now.timeIntervalSince(state.preferences.lastWatch ?? .distantPast) > 900 { await scan(manual: false) }
        }
        let day = now.formatted(.iso8601.year().month().day())
        if state.preferences.dayStamp != day { state.preferences.dayStamp = day; state.preferences.dailyRuns = 0; save() }
        guard AutonomyPolicy.canRun(preferences: state.preferences, now: now, busy: busy), !companies.isEmpty else { return }
        let company = companies.first { $0.id == state.preferences.autonomousCompanyID } ?? companies[state.preferences.dailyRuns % companies.count]
        state.preferences.lastAutonomous = now; state.preferences.dailyRuns += 1; state.preferences.selectedAgent = "director"; save()
        let brief = state.preferences.autonomousBrief?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let history = state.missions.filter { $0.companyID == company.id && $0.status == "Completada" }.prefix(3).flatMap { $0.messages.filter { $0.role == "assistant" }.map(\\.text) }.joined(separator: "\\n")
        run((brief.isEmpty ? "Revisa el objetivo y las tareas pendientes. Prepara una propuesta concreta o un entregable que haga avanzar la empresa. Evita repetir resultados. Guarda próximos pasos útiles como tareas locales." : brief) + "\\nTrabajo anterior:\\n" + String(history.suffix(16000)), companyID: company.id, fresh: true, proactive: true)
    }
}

enum AutonomyPolicy {
    static func canRun(preferences: Preferences, now: Date, busy: Bool, calendar: Calendar = .current) -> Bool {
        guard preferences.autonomous, !busy, preferences.dailyRuns < max(1, preferences.dailyLimit), now.timeIntervalSince(preferences.lastAutonomous ?? .distantPast) >= Double(max(1, preferences.intervalHours)) * 3600 else { return false }
        if preferences.quietHours == true {
            let hour = calendar.component(.hour, from: now), start = preferences.quietStart ?? 23, end = preferences.quietEnd ?? 7
            if start == end { return false }
            if start > end ? (hour >= start || hour < end) : (hour >= start && hour < end) { return false }
        }
        return true
    }
}
'''
tail=tail.replace('        if state.preferences.watchCalendar &&', '        guard !scanning else { return }; scanning = true; defer { scanning = false }\n        if state.preferences.watchCalendar &&')
p.write_text(head+tail+scheduler)
