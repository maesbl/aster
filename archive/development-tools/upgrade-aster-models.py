from pathlib import Path
p=Path('outputs/Aster-macOS/Sources/Models.swift')
s=p.read_text(); api=s[s.index('final class AgentAPI:'):]
Path('outputs/Aster-macOS/Sources/AgentAPI.swift').write_text('import Foundation\n\n'+api)
s=s[:s.index('final class AgentAPI:')]
s=s.replace('    var style: AvatarStyle\n','    var style: AvatarStyle\n    var personality: String?\n')
s=s.replace('    var notes: String = ""\n','    var notes: String = ""\n    var archived: Bool?\n')
s=s.replace('    var updated = Date()\n','    var updated = Date()\n    var archived: Bool?\n    var pinned: Bool?\n    var configuration: String?\n    var previousSessions: [String]?\n    var started: Date?\n    var elapsedSeconds: Double?\n    var attachmentNames: [String]?\n    var artifactRecords: [AgentArtifact]?\n')
s=s.replace('    var cloudURL = ""\n','''    var cloudURL = ""
    var intelligence: IntelligenceSettings?
    var autonomousCompanyID: UUID?
    var quietHours: Bool?
    var quietStart: Int?
    var quietEnd: Int?
    var autonomousBrief: String?
''')
a=s.index('struct SavedState: Codable {'); b=s.index('\nenum AsterError:',a)
s=s[:a]+'''struct IntelligenceSettings: Codable, Equatable {
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
    init() {}
    enum CodingKeys: String, CodingKey { case specialists, companies, missions, inbox, preferences, memories, tasks, toolReceipts }
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
''' +s[b:]
s=s.replace('case session(String), turn(String), text(String, String, Bool), activity(String), completed, cancelled, failure(String)', 'case session(String), turn(String), text(String, String, Bool), activity(String), actions(String, [PendingToolCall]), completed, cancelled, failure(String)')
s=s.replace('        if type == "agent.session.requires_action" { return .failure("El agente necesita una autorización o una herramienta que esta versión todavía no puede atender. La sesión se conserva para recuperarla.") }','''        if type == "agent.session.requires_action", let id = session?["id"] as? String {
            let actions = session?["required_actions"] as? [[String: Any]] ?? []
            let calls = actions.compactMap(PendingToolCall.decode)
            if calls.count != actions.count || calls.isEmpty { return .failure("La sesión requiere una acción externa que necesita revisión. Puedes recuperar su estado.") }
            return .actions(id, calls)
        }
        if type.contains("web_search") { return .activity("Investigando fuentes") }
        if type.contains("command") || type.contains("shell") { return .activity("Creando y comprobando archivos") }''')
s=s.replace('        return message\n    }\n}', '''        if ["invalid_api_key", "authentication_error"].contains(code ?? "") { return "La conexión de OpenAI no es válida. Comprueba la configuración local." }
        if code == "rate_limit_exceeded" { return "OpenAI está limitando las solicitudes. Espera unos momentos y recupera el estado antes de reenviar." }
        return message
    }
}''',1)
p.write_text(s)
