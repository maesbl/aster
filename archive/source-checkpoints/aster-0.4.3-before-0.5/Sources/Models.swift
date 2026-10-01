import Foundation
import SwiftUI

struct Specialist: Identifiable, Codable {
    var id: String
    var name: String
    var role: String
    var detail: String
    var style: AvatarStyle
    var personality: String?
    static let defaults: [Specialist] = [
        .init(id: "director", name: "Aster", role: "Dirección", detail: "Conecta ideas, organiza el equipo y convierte objetivos en próximos pasos.", style: .init(form: .pebble, tint: .lilac)),
        .init(id: "growth", name: "Milo", role: "Marketing", detail: "Posicionamiento, campañas, contenidos y crecimiento con resultados medibles.", style: .init(form: .pill, tint: .peach)),
        .init(id: "builder", name: "Nova", role: "Desarrollo", detail: "Webs, productos y código. Construye, verifica y explica sus decisiones.", style: .init(form: .orbit, tint: .mint)),
        .init(id: "strategy", name: "Sage", role: "Negocio", detail: "Planes de negocio, investigación y escenarios con supuestos explícitos.", style: .init(form: .pebble, tint: .pearl)),
        .init(id: "personal", name: "Lumi", role: "Personal", detail: "Te ayuda a pensar, crear y cuidar de tu agenda y tus prioridades.", style: .init(form: .pill, tint: .ink)),
        .init(id: "study", name: "Atlas", role: "Aprendizaje", detail: "Aprende contigo, explica paso a paso y te ayuda con documentos, Excel y tareas en tu Mac.", style: .init(form: .orbit, tint: .pearl))
    ]
}
struct Company: Identifiable, Codable {
    var id = UUID()
    var name: String
    var goal: String
    var notes: String = ""
    var archived: Bool?
}
struct Message: Identifiable, Codable {
    var id = UUID()
    var role: String
    var text: String
    var date = Date()
}
struct Mission: Identifiable, Codable {
    var id = UUID()
    var title: String
    var specialistID: String
    var companyID: UUID?
    var messages: [Message] = []
    var sessionID: String?
    var turnID: String?
    var status = "Lista"
    var error: String?
    var updated = Date()
    var archived: Bool?
    var pinned: Bool?
    var configuration: String?
    var previousSessions: [String]?
    var started: Date?
    var elapsedSeconds: Double?
    var attachmentNames: [String]?
    var artifactRecords: [AgentArtifact]?
}
struct InboxNote: Identifiable, Codable {
    var id = UUID()
    var title: String
    var text: String
    var date = Date()
    var read = false
    var fingerprint: String
    var missionID: UUID?
}
struct Preferences: Codable {
    var selectedAgent = "director"
    var notifications = false
    var watchCalendar = false
    var watchMail = false
    var watchReminders: Bool?
    var voice: String?
    var voiceEngine: String?
    var agentVoices: [String: String]?
    var narrateComputer: Bool?
    var autonomous = false
    var intervalHours = 6
    var dailyLimit = 2
    var lastAutonomous: Date?
    var dayStamp = ""
    var dailyRuns = 0
    var lastWatch: Date?
    var cloudURL = ""
    var intelligence: IntelligenceSettings?
    var autonomousCompanyID: UUID?
    var quietHours: Bool?
    var quietStart: Int?
    var quietEnd: Int?
    var autonomousBrief: String?
}
struct IntelligenceSettings: Codable, Equatable {
    var model = "gpt-6-astra"
    var effort = "medium"
    var responseLanguage = "auto"
    var tone = "warm"
    var detail = "balanced"
    var webSearch = true
    var delegation = true
    var maxAgents = 3
    var useMemory = true
    var automaticMemory = false
    var shareSources = false
    var maxMinutes = 12
    var userName = ""
    var instructions = ""
}
struct MemoryEntry: Identifiable, Codable {
    var id = UUID()
    var text: String
    var date = Date()
    var companyID: UUID?
}
struct WorkTask: Identifiable, Codable {
    var id = UUID()
    var title: String
    var companyID: UUID?
    var specialistID: String = "director"
    var done = false
    var created = Date()
    var due: Date?
    var missionID: UUID?
}
struct ToolReceipt: Codable {
    var sessionID: String
    var turnID: String
    var callID: String
    var output: String
}
struct MailItem: Codable {
    var id: String
    var subject: String
    var sender: String
    var received: Date
    var body: String?
}
struct ReminderItem: Identifiable {
    var id: String
    var title: String
    var notes: String
    var list: String
    var completed: Bool
    var due: Date?
}
struct ScheduledAlert: Identifiable, Codable {
    var id = UUID()
    var text: String
    var date: Date
    var recurrence: String = "none"
    var scheduled = false
    var toolKey: String?
}
struct HealthMetric: Identifiable, Codable {
    var id: String
    var label: String
    var value: String
    var unit: String
    var date: Date
    var source: String
}
struct HealthSnapshot: Codable {
    var imported: Date
    var filename: String
    var metrics: [HealthMetric]
    var recordCount: Int
}
struct Attachment: Identifiable {
    var id = UUID()
    var name: String
    var data: Data
    var path: String { "/workspace/inputs/" + id.uuidString + "-" + name }
    static let maximumBytes = 10 * 1024 * 1024
}
struct SavedState: Codable {
    var specialists = Specialist.defaults
    var companies: [Company] = []
    var missions: [Mission] = []
    var inbox: [InboxNote] = []
    var preferences = Preferences()
    var memories: [MemoryEntry] = []
    var tasks: [WorkTask] = []
    var toolReceipts: [ToolReceipt] = []
    var alerts: [ScheduledAlert] = []
    var computerRuns: [ComputerRun] = []
    var health: HealthSnapshot?
    var desktopChats: [String: UUID] = [:]
    var desktopDrafts: [String: String] = [:]
    init() {}
    enum CodingKeys: String, CodingKey { case specialists, companies, missions, inbox, preferences, memories, tasks, toolReceipts, alerts, computerRuns, health, desktopChats, desktopDrafts }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        specialists = try c.decodeIfPresent([Specialist].self, forKey: .specialists) ?? Specialist.defaults
        if specialists.isEmpty { specialists = Specialist.defaults }
        companies = try c.decodeIfPresent([Company].self, forKey: .companies) ?? []
        missions = try c.decodeIfPresent([Mission].self, forKey: .missions) ?? []
        inbox = try c.decodeIfPresent([InboxNote].self, forKey: .inbox) ?? []
        preferences = try c.decodeIfPresent(Preferences.self, forKey: .preferences) ?? Preferences()
        memories = try c.decodeIfPresent([MemoryEntry].self, forKey: .memories) ?? []
        tasks = try c.decodeIfPresent([WorkTask].self, forKey: .tasks) ?? []
        toolReceipts = try c.decodeIfPresent([ToolReceipt].self, forKey: .toolReceipts) ?? []
        alerts = try c.decodeIfPresent([ScheduledAlert].self, forKey: .alerts) ?? []
        computerRuns = try c.decodeIfPresent([ComputerRun].self, forKey: .computerRuns) ?? []
        health = try c.decodeIfPresent(HealthSnapshot.self, forKey: .health)
        desktopChats = try c.decodeIfPresent([String: UUID].self, forKey: .desktopChats) ?? [:]
        desktopDrafts = try c.decodeIfPresent([String: String].self, forKey: .desktopDrafts) ?? [:]
    }
}
struct PendingToolCall {
    var turnID: String
    var callID: String
    var name: String
    var arguments: [String: Any]
    static func decode(_ action: [String: Any]) -> PendingToolCall? {
        guard action["type"] as? String == "function_call", let turn = action["turn_id"] as? String,
              let call = action["call_id"] as? String, let name = action["name"] as? String else { return nil }
        let arguments = action["arguments"] as? [String: Any] ?? (action["arguments"] as? String).flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] } ?? [:]
        return .init(turnID: turn, callID: call, name: name, arguments: arguments)
    }
}

enum AsterError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let value) = self { return value }; return nil }
}

enum AgentEvent {
    case session(String), turn(String), text(String, String, Bool), activity(String), actions(String, [PendingToolCall]), completed, cancelled, failure(String)
    static func decode(_ data: Data) -> AgentEvent? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let type = object["type"] as? String else { return nil }
        let session = object["session"] as? [String: Any]
        let turn = object["turn"] as? [String: Any]
        if type.contains("output_text"), let subagent = object["subagent_id"], !(subagent is NSNull) { return nil }
        if type == "agent.session.created", let id = session?["id"] as? String { return .session(id) }
        if type == "agent.session.turn.started", turn?["subagent_id"] is NSNull || turn?["subagent_id"] == nil, let id = turn?["id"] as? String { return .turn(id) }
        if type == "agent.session.turn.output_text.delta", let text = object["delta"] as? String { return .text(object["item_id"] as? String ?? "output", text, false) }
        if type == "agent.session.turn.output_text.done", let text = object["text"] as? String { return .text(object["item_id"] as? String ?? "output", text, true) }
        if type == "agent.session.turn.completed", turn?["subagent_id"] is NSNull || turn?["subagent_id"] == nil { return .completed }
        if type == "agent.session.turn.cancelled", turn?["subagent_id"] is NSNull || turn?["subagent_id"] == nil { return .cancelled }
        if type == "agent.session.turn.failed", !(turn?["subagent_id"] is NSNull) && turn?["subagent_id"] != nil { return .activity("Un especialista encontró un problema") }
        if type == "error" || type == "agent.session.failed" || type == "agent.session.environment.failed" || type == "agent.session.turn.failed" {
            let error = (object["error"] as? [String: Any]) ?? (turn?["error"] as? [String: Any]) ?? (session?["error"] as? [String: Any])
            return .failure(friendlyError(error?["message"] as? String ?? "La sesión no pudo terminar.", code: error?["code"] as? String))
        }
        if type == "agent.session.requires_action", let id = session?["id"] as? String {
            let actions = session?["required_actions"] as? [[String: Any]] ?? []
            let calls = actions.compactMap(PendingToolCall.decode)
            if calls.count != actions.count || calls.isEmpty { return .failure("La sesión requiere una acción externa que necesita revisión. Puedes recuperar su estado.") }
            return .actions(id, calls)
        }
        if type.contains("web_search") { return .activity("Investigando fuentes") }
        if type.contains("command") || type.contains("shell") { return .activity("Creando y comprobando archivos") }
        if type.contains("subagent") { return .activity("El equipo está colaborando") }
        return nil
    }
    static func friendlyError(_ message: String, code: String? = nil) -> String {
        if ["usage_limit_exceeded", "insufficient_quota", "credit_balance_exhausted"].contains(code ?? "") || message.lowercased().contains("billing limit") {
            return "La cuenta de OpenAI ha alcanzado su límite de uso o facturación. Revisa el saldo y los límites para que los agentes puedan responder."
        }
        if ["invalid_api_key", "authentication_error"].contains(code ?? "") { return "La conexión de OpenAI no es válida. Comprueba la configuración local." }
        if code == "rate_limit_exceeded" { return "OpenAI está limitando las solicitudes. Espera unos momentos y recupera el estado antes de reenviar." }
        return message
    }
}

struct SSEParser {
    private(set) var rootTurnID: String?
    private var dataLines: [String] = []
    private var lineBytes = Data()
    mutating func feed(_ byte: UInt8) throws -> AgentEvent? {
        if byte == 10 {
            if lineBytes.last == 13 { lineBytes.removeLast() }
            let line = String(decoding: lineBytes, as: UTF8.self); lineBytes.removeAll(keepingCapacity: true)
            return append(line)
        }
        lineBytes.append(byte)
        if lineBytes.count > 2_000_000 { throw AsterError.message("La respuesta supera el tamaño esperado. Recupera la sesión para consultar el resultado guardado.") }
        return nil
    }
    mutating func append(_ line: String) -> AgentEvent? {
        if line.isEmpty { return finish() }
        if line.hasPrefix("data:") {
            var value = String(line.dropFirst(5)); if value.hasPrefix(" ") { value.removeFirst() }
            dataLines.append(value)
        }
        return nil
    }
    mutating func finish() -> AgentEvent? {
        if !lineBytes.isEmpty {
            let line = String(decoding: lineBytes, as: UTF8.self); lineBytes.removeAll()
            if line.hasPrefix("data:") { dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)) }
        }
        defer { dataLines = [] }
        let data = Data(dataLines.joined(separator: "\n").utf8)
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let turn = object["turn"] as? [String: Any]
            let subagent = object["subagent_id"] ?? turn?["subagent_id"]
            if subagent == nil || subagent is NSNull {
                if let id = object["turn_id"] as? String ?? turn?["id"] as? String { rootTurnID = id }
            }
        }
        return AgentEvent.decode(data)
    }
}

struct AgentArtifact: Identifiable, Codable {
    var id: String
    var path: String
    var turnID: String?
    var sessionID: String?
}
