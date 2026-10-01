import AppKit
import Combine

@MainActor final class ComputerController: ObservableObject {
    @Published private(set) var active = false
    @Published private(set) var paused = false
    @Published private(set) var phase = "Listo para ayudarte"
    @Published private(set) var steps: [ComputerStep] = []
    @Published private(set) var result = ""
    @Published private(set) var error = ""
    @Published private(set) var question = ""
    @Published private(set) var taskText = ""
    @Published private(set) var screenAllowed = false
    @Published private(set) var controlAllowed = false
    @Published var selectedDisplay = CGMainDisplayID()
    let preview = ScreenPreview()
    lazy var desktop = MacDesktop(preview: preview)
    var onBegin: (() -> Void)?
    var onEnd: (() -> Void)?
    var onNarration: ((String) -> Void)?
    var onFinished: ((ComputerRun) -> Void)?
    private var job: Task<Void, Never>?
    private var deadline: Task<Void, Never>?
    private var escapeMonitor: Any?
    private var generation = UUID()
    private var reply = ""
    private var runningAgentID = "study"
    init() { refreshPermissions() }
    func refreshPermissions() {
        let screen = MacDesktop.canSee; let control = MacDesktop.canControl
        if screenAllowed != screen { screenAllowed = screen }
        if controlAllowed != control { controlAllowed = control }
    }
    func requestScreen() { MacDesktop.requestScreen(); refreshPermissions() }
    func requestControl() { MacDesktop.requestControl(); refreshPermissions() }
    func showPreview() {
        refreshPermissions(); guard screenAllowed else { error = "Permite la grabación de pantalla para ver el Mac en directo."; return }
        Task { do { try await desktop.start(displayID: selectedDisplay); error = "" } catch { self.error = error.localizedDescription } }
    }
    func hidePreview() { guard !active else { return }; Task { await desktop.stop() } }
    func start(_ text: String, agent: Specialist, settings: IntelligenceSettings, api: AgentAPI? = nil, backend: DesktopBackend? = nil, needsPermissions: Bool = true) {
        let task = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !active, !task.isEmpty else { return }; refreshPermissions()
        if needsPermissions && (!screenAllowed || !controlAllowed) { error = "Activa Pantalla y Accesibilidad antes de empezar. Los botones de abajo abren esos permisos."; return }
        active = true; paused = false; phase = "Preparando la pantalla"; steps = []; result = ""; error = ""; question = ""; taskText = task; reply = ""; runningAgentID = agent.id
        let token = UUID(); generation = token; onBegin?()
        if needsPermissions {
            escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel]) { [weak self] event in
                guard event.cgEvent?.getIntegerValueField(.eventSourceUserData) != 0x4153544552 else { return }
                Task { @MainActor in if event.type == .keyDown && event.keyCode == 53 { self?.stop() } else if self?.active == true && self?.paused == false { self?.pause() } }
            }
        }
        deadline = Task { [weak self] in try? await Task.sleep(for: .seconds(Double(settings.maxMinutes) * 60)); guard !Task.isCancelled, self?.generation == token else { return }; self?.stop(reason: "Se ha alcanzado el tiempo máximo de la tarea.") }
        job = Task { [weak self] in
            guard let self else { return }
            do {
                let api = try api ?? AgentAPI(); let engine = backend ?? self.desktop
                if backend == nil { try await self.desktop.start(displayID: self.selectedDisplay) }
                let language = settings.responseLanguage == "auto" ? (UserDefaults.standard.string(forKey: "AsterLanguage") ?? "es") : settings.responseLanguage
                try await self.loop(task: task, agent: agent, settings: settings, language: language, api: api, backend: engine, token: token)
                guard self.generation == token else { return }
                self.finish(agentID: agent.id, status: self.error.isEmpty ? "Completada" : "Necesita revisión")
            } catch is CancellationError { }
            catch { guard self.generation == token else { return }; self.error = error.localizedDescription; self.phase = "Necesita revisión"; self.finish(agentID: agent.id, status: "Necesita revisión") }
        }
    }
    private func ready(_ token: UUID) async throws {
        while paused { try Task.checkCancellation(); guard generation == token, active else { throw CancellationError() }; try await Task.sleep(for: .milliseconds(150)) }
        try Task.checkCancellation(); guard generation == token, active else { throw CancellationError() }
    }
    private func loop(task: String, agent: Specialist, settings: IntelligenceSettings, language: String, api: AgentAPI, backend: DesktopBackend, token: UUID) async throws {
        var previous: String?; var pending: [[String: Any]] = []
        for _ in 0..<60 {
            try await ready(token)
            let frame = try await backend.capture(); try await ready(token)
            phase = "Decidiendo el siguiente paso"
            var input = pending
            input.append(ComputerPrompt.screenshotInput(frame, instruction: previous == nil ? "User's requested task: " + task : "This is the current screen after the last action. " + (reply.isEmpty ? "Check the result and continue the requested task." : "The user says: " + reply)))
            reply = ""
            var body: [String: Any] = ["model": settings.model, "instructions": ComputerPrompt.instructions(agent: agent, language: language), "input": input, "tools": [ComputerPrompt.tool], "tool_choice": ["type": "function", "name": "aster_desktop"], "parallel_tool_calls": false, "reasoning": ["effort": settings.effort], "max_output_tokens": 2200]
            if let previous { body["previous_response_id"] = previous }
            let response = try await api.response(body); try await ready(token)
            if let issue = response["error"] as? [String: Any] { throw AsterError.message(AgentEvent.friendlyError(issue["message"] as? String ?? "La IA no pudo continuar.", code: issue["code"] as? String)) }
            guard response["status"] as? String == "completed", let id = response["id"] as? String else { throw AsterError.message("La respuesta se interrumpió antes de completar el siguiente paso. Revisa la pantalla y vuelve a iniciar la tarea.") }
            let calls = (response["output"] as? [[String: Any]] ?? []).filter { $0["type"] as? String == "function_call" && $0["name"] as? String == "aster_desktop" }
            guard calls.count == 1, let callID = calls[0]["call_id"] as? String, let arguments = calls[0]["arguments"] as? String else { throw AsterError.message("La IA no devolvió una única acción válida. No se ha movido el cursor.") }
            let action = try JSONDecoder().decode(DesktopAction.self, from: Data(arguments.utf8)); try action.validate(geometry: frame.geometry, active: active && !paused)
            previous = id; phase = action.explanation
            steps.append(.init(text: action.explanation, action: action.action)); onNarration?(action.explanation)
            if action.action == "finish" { result = action.text ?? action.explanation; phase = "Tarea terminada"; return }
            if action.action == "ask_user" {
                question = action.text ?? action.reason ?? action.explanation; paused = true; phase = "Esperando tu respuesta"; onEnd?()
                try await ready(token); question = ""; onBegin?()
                pending = [["type": "function_call_output", "call_id": callID, "output": "The user has responded in Aster. Read the next screenshot and user reply. Do not assume that any permission or external action has been granted."]]
                continue
            }
            // Announce before posting any input. Pausing during narration blocks the action.
            try await ready(token)
            do {
                try await backend.perform(action, geometry: frame.geometry, allowed: { [weak self] in self?.active == true && self?.paused == false && self?.generation == token })
                pending = [["type": "function_call_output", "call_id": callID, "output": "Action posted. Inspect the next fresh screenshot to verify its effect before proceeding."]]
            } catch is CancellationError { throw CancellationError() }
            catch { pending = [["type": "function_call_output", "call_id": callID, "output": "Action failed: " + error.localizedDescription + ". Inspect current screen. Do not claim success."]]; self.steps.append(.init(text: error.localizedDescription, action: "error")) }
        }
        error = "Se ha alcanzado el límite de 60 pasos. Revisa el resultado antes de continuar."; phase = "Necesita revisión"
    }
    func pause() { guard active else { return }; paused = true; phase = "En pausa"; onEnd?() }
    func resume(_ message: String = "") { guard active, paused else { return }; reply = message; question = ""; onBegin?(); paused = false; phase = "Continuando" }
    func stop(reason: String = "Tarea detenida") {
        guard active else { return }; job?.cancel(); deadline?.cancel(); generation = UUID(); active = false; paused = false; question = ""; phase = reason; cleanupMonitor(); onEnd?()
        onFinished?(.init(task: taskText, agentID: runningAgentID, steps: steps, result: result, status: "Detenida"))
        Task { await desktop.stop() }
    }
    private func finish(agentID: String, status: String) { active = false; paused = false; question = ""; deadline?.cancel(); cleanupMonitor(); onFinished?(.init(task: taskText, agentID: agentID, steps: steps, result: result.isEmpty ? error : result, status: status)); onEnd?(); Task { await desktop.stop() } }
    private func cleanupMonitor() { if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }; escapeMonitor = nil }
}
