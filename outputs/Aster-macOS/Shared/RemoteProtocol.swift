import Foundation
import CryptoKit

enum RemoteError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
struct RemotePairing: Codable, Equatable {
    var version = 1
    var relay: String
    var room = UUID().uuidString.lowercased()
    var secret: Data
    var name: String
    init(relay: String, name: String) throws {
        self.relay = relay.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = String(name.prefix(80))
        secret = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        try validate()
    }
    func validate(allowLocal: Bool = RemotePairing.localDevelopment) throws {
        guard version == 1, secret.count == 32, UUID(uuidString: room) != nil, !name.isEmpty, name.count <= 80,
              let url = URLComponents(string: relay), let host = url.host, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil, url.path.isEmpty || url.path == "/",
              url.scheme == "wss" || (allowLocal && url.scheme == "ws" && ["127.0.0.1", "localhost", "::1"].contains(host)) else {
            throw RemoteError.message("El enlace no es válido. Usa el código creado en Aster y un servidor wss://.")
        }
    }
    static var localDevelopment: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    var code: String { "aster://pair#" + ((try? JSONEncoder().encode(self)) ?? Data()).base64URLEncoded }
    static func parse(_ code: String) throws -> Self {
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count < 3000, code.hasPrefix("aster://pair#"), let data = Data(base64URL: String(code.dropFirst("aster://pair#".count))) else { throw RemoteError.message("Ese código de enlace no es válido.") }
        let pairing = try JSONDecoder().decode(Self.self, from: data); try pairing.validate(); return pairing
    }
    private func derived(_ purpose: String) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: secret), salt: Data(room.utf8), info: Data(("aster-remote-v1/" + purpose).utf8), outputByteCount: 32)
    }
    var relayToken: String { derived("relay-auth").withUnsafeBytes { Data($0).base64URLEncoded } }
    func cipherKey(sender: RemoteRole) -> SymmetricKey { derived("cipher/" + sender.rawValue) }
}
extension Data {
    var base64URLEncoded: String { base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
    init?(base64URL: String) {
        let text = base64URL.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        self.init(base64Encoded: text + String(repeating: "=", count: (4 - text.count % 4) % 4))
    }
}
enum RemoteRole: String, Codable { case mac, phone; var peer: Self { self == .mac ? .phone : .mac } }
enum RemoteKind: String, Codable { case hello, snapshot, conversation, command, receipt, frame, screenEnded }
struct RemotePacket: Codable {
    var version = 1
    var id = UUID()
    var sentAt = Date()
    var kind: RemoteKind
    var payload: Data
    init<T: Encodable>(_ kind: RemoteKind, _ value: T) throws { self.kind = kind; payload = try JSONEncoder().encode(value) }
    func decode<T: Decodable>(_ type: T.Type) throws -> T { try JSONDecoder().decode(type, from: payload) }
}
struct RemoteCipher {
    let pairing: RemotePairing
    let role: RemoteRole
    private var seen: [UUID: Date] = [:]
    init(pairing: RemotePairing, role: RemoteRole) { self.pairing = pairing; self.role = role }
    func seal(_ packet: RemotePacket) throws -> Data {
        let data = try JSONEncoder().encode(packet)
        guard data.count < 1_900_000 else { throw RemoteError.message("El mensaje es demasiado grande.") }
        return try AES.GCM.seal(data, using: pairing.cipherKey(sender: role), authenticating: Data((pairing.room + "/" + role.rawValue).utf8)).combined!
    }
    mutating func open(_ data: Data, now: Date = Date()) throws -> RemotePacket {
        guard data.count <= 2_000_000 else { throw RemoteError.message("Mensaje remoto demasiado grande.") }
        let plain = try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: pairing.cipherKey(sender: role.peer), authenticating: Data((pairing.room + "/" + role.peer.rawValue).utf8))
        let packet = try JSONDecoder().decode(RemotePacket.self, from: plain)
        guard packet.version == 1, abs(now.timeIntervalSince(packet.sentAt)) < 90, seen[packet.id] == nil else { throw RemoteError.message("Mensaje remoto caducado o repetido.") }
        seen = seen.filter { now.timeIntervalSince($0.value) < 180 }
        guard seen.count < 6000 else { throw RemoteError.message("Demasiados mensajes remotos.") }
        seen[packet.id] = now; return packet
    }
}
struct RemoteAgent: Codable, Identifiable { var id: String; var name: String; var role: String; var busy: Bool }
struct RemoteMission: Codable, Identifiable { var id: UUID; var title: String; var agentID: String; var status: String; var activity: String; var updated: Date }
struct RemoteCompany: Codable, Identifiable { var id: UUID; var name: String }
struct RemoteMessage: Codable, Identifiable { var id: UUID; var role: String; var text: String }
struct RemoteConversation: Codable { var id: UUID; var messages: [RemoteMessage]; var error: String? }
struct RemoteSnapshot: Codable {
    var name: String; var agents: [RemoteAgent]; var missions: [RemoteMission]; var companies: [RemoteCompany]
    var connectionReady: Bool; var screenAllowed: Bool; var controlAllowed: Bool; var canControlRemotely: Bool
    var computerActive: Bool; var computerPaused: Bool; var computerPhase: String; var computerQuestion: String; var computerResult: String
    var receipts: [RemoteReceipt] = []
    var time = Date()
}
struct RemoteFrame: Codable { var id = UUID(); var width: Int; var height: Int; var jpeg: Data; var time = Date() }
struct RemotePoint: Codable { var x: Double; var y: Double }
struct RemoteInput: Codable {
    var action: String; var frameID: UUID?; var x: Double?; var y: Double?; var text: String?; var key: String?; var direction: String?; var app: String?; var path: [RemotePoint]?
}
enum RemoteOperation: String, Codable { case snapshot, subscribe, chat, stopMission, startComputer, pauseComputer, resumeComputer, stopComputer, screenStart, screenStop, input }
struct RemoteCommand: Codable, Identifiable {
    var id = UUID(); var created = Date(); var operation: RemoteOperation
    var text: String?; var agentID: String?; var missionID: UUID?; var companyID: UUID?; var input: RemoteInput?
    func validate(now: Date = Date()) throws {
        guard abs(now.timeIntervalSince(created)) < 60, (text?.count ?? 0) <= 24000 else { throw RemoteError.message("La orden ha caducado o es demasiado larga. Revisa el estado antes de enviarla de nuevo.") }
        if [.chat, .startComputer].contains(operation) && (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw RemoteError.message("Escribe una tarea antes de enviarla.") }
    }
}
struct RemoteReceipt: Codable, Identifiable {
    var id: UUID; var status: String; var message: String; var missionID: UUID?; var date = Date()
}
// A claim is persisted before executing a side effect. A crash cannot silently replay it.
struct RemoteLedger: Codable {
    var receipts: [RemoteReceipt] = []
    mutating func claim(_ command: RemoteCommand, now: Date = Date()) throws -> RemoteReceipt? {
        if let existing = receipts.first(where: { $0.id == command.id }) { return existing }
        try command.validate(now: now)
        receipts.removeAll { now.timeIntervalSince($0.date) > 86_400 }
        guard receipts.count < 5000 else { throw RemoteError.message("Se ha alcanzado el límite de órdenes del día.") }
        receipts.append(.init(id: command.id, status: "received", message: "Recibida. Si la conexión se interrumpe, comprueba su resultado antes de repetirla.")); return nil
    }
    mutating func finish(_ receipt: RemoteReceipt) { if let index = receipts.firstIndex(where: { $0.id == receipt.id }) { receipts[index] = receipt } }
}
