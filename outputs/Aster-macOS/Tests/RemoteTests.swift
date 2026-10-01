import Foundation
import CryptoKit

@main struct RemoteTests {
    static func check(_ condition: @autoclosure () throws -> Bool, _ text: String) { if (try? condition()) != true { fatalError(text) } }
    static func rejects(_ text: String, _ body: () throws -> Void) { do { try body(); fatalError(text) } catch {} }
    @MainActor static func wait(_ text: String, _ condition: () -> Bool) async throws {
        for _ in 0..<100 { if condition() { return }; try await Task.sleep(for: .milliseconds(100)) }
        fatalError(text)
    }
    @MainActor static func main() async throws {
        let pairing = try RemotePairing(relay: "ws://127.0.0.1:8787", name: "Aster Test Mac")
        check(try RemotePairing.parse(pairing.code) == pairing, "QR pairing round trip")
        rejects("Production must reject cleartext") { try pairing.validate(allowLocal: false) }
        for endpoint in ["ws://example.com", "wss://user:pass@example.com", "wss://example.com?token=leak", "file:///tmp/server", "wss://example.com/other"] {
            rejects("Invalid relay endpoint") { _ = try RemotePairing(relay: endpoint, name: "Test") }
        }
        let mac = RemoteCipher(pairing: pairing, role: .mac); var phoneCipher = RemoteCipher(pairing: pairing, role: .phone)
        let packet = try RemotePacket(.hello, "fixture-private-text"); let sealed = try mac.seal(packet)
        check(!sealed.base64EncodedString().contains("fixture-private-text"), "No plaintext envelope")
        let opened = try phoneCipher.open(sealed); check(try opened.decode(String.self) == "fixture-private-text", "Encrypted round trip")
        rejects("Replay rejected") { _ = try phoneCipher.open(sealed) }
        var reflected = RemoteCipher(pairing: pairing, role: .mac)
        rejects("Reflection rejected") { _ = try reflected.open(sealed) }
        var wrong = RemoteCipher(pairing: try RemotePairing(relay: pairing.relay, name: "Other"), role: .phone)
        rejects("Wrong pairing rejected") { _ = try wrong.open(sealed) }
        var altered = sealed; altered[altered.count - 1] ^= 1
        rejects("Tamper rejected") { _ = try phoneCipher.open(altered) }
        var old = try RemotePacket(.hello, "expired"); old.sentAt = Date().addingTimeInterval(-100)
        rejects("Expired envelope rejected") { _ = try phoneCipher.open(mac.seal(old)) }
        let liveFile = CommandLine.arguments.dropFirst().first
        let command = RemoteCommand(operation: .chat, text: liveFile == nil ? "Fixture task" : "Reply with exactly ASTER_REMOTE_OK. Do not use tools, create files or read anything else.", agentID: "study")
        var ledger = RemoteLedger(); check(try ledger.claim(command) == nil, "First command claimed")
        ledger = try JSONDecoder().decode(RemoteLedger.self, from: JSONEncoder().encode(ledger))
        check(try ledger.claim(command)?.status == "received", "Durable uncertain claim blocks replay")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("aster-remote-test-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = AsterStore(directory: folder.appendingPathComponent("store"), startServices: false, apiFactory: { if let liveFile { return try AgentAPI(environmentFile: liveFile) }; throw AsterError.message("Offline test fixture; no provider call") })
        store.connectionReady = true; store.page = "Personajes"
        var settings = store.settings; settings.model = "gpt-6-luna"; settings.effort = "low"; settings.useMemory = false; settings.automaticMemory = false; settings.shareSources = false; settings.webSearch = false; settings.delegation = false; settings.maxMinutes = 2; store.settings = settings
        let bridge = MacRemoteBridge(store: store, pairing: pairing, storageDirectory: folder.appendingPathComponent("receipts"), restoresConfiguration: false)
        let phone = RemoteConnection(); var snapshots: [RemoteSnapshot] = []; var receipts: [RemoteReceipt] = []
        phone.onPacket = { packet in
            if packet.kind == .snapshot, let value = try? packet.decode(RemoteSnapshot.self) { snapshots.append(value) }
            if packet.kind == .receipt, let value = try? packet.decode(RemoteReceipt.self) { receipts.append(value) }
        }
        bridge.start(); phone.connect(pairing, role: .phone)
        defer { phone.disconnect(); bridge.stop() }
        try await wait("Real WebSocket handshake", { phone.peerOnline && bridge.connection.peerOnline })
        try await phone.send(.command, RemoteCommand(operation: .snapshot))
        try await wait("Authenticated Mac snapshot", { !snapshots.isEmpty })
        check(snapshots[0].agents.count == 6, "All six real Mac agents shared")
        try await phone.send(.command, command)
        try await wait("Task accepted", { receipts.contains(where: { $0.id == command.id }) })
        check(receipts.last?.status == "accepted" && store.state.missions.count == 1, "Remote command invokes the actual store")
        check(store.page == "Personajes", "Remote task does not steal Mac navigation")
        try await phone.send(.command, command)
        try await wait("Duplicate receipt returned", { receipts.filter { $0.id == command.id }.count == 2 })
        check(store.state.missions.count == 1, "Duplicate command never starts a second task")
        phone.disconnect(); try await wait("Disconnect recognized", { !bridge.connection.peerOnline })
        phone.connect(pairing, role: .phone); try await wait("Reconnect works", { phone.peerOnline })
        try await phone.send(.command, command)
        try await wait("Receipt survives reconnect", { receipts.filter { $0.id == command.id }.count == 3 })
        check(store.state.missions.count == 1, "Reconnect never replays work")
        let invalid = RemoteCommand(operation: .chat, text: "Wrong agent", agentID: "nonexistent")
        try await phone.send(.command, invalid); try await wait("Invalid agent rejected", { receipts.contains(where: { $0.id == invalid.id && $0.status == "error" }) })
        check(store.state.missions.count == 1, "Invalid agent cannot dispatch")
        if let liveFile {
            for _ in 0..<600 where store.busy { try await Task.sleep(for: .milliseconds(100)) }
            let result = store.state.missions[0]
            if let session = result.sessionID { _ = try? await AgentAPI(environmentFile: liveFile).json("/" + session, method: "DELETE") }
            check(result.status == "Completada" && result.messages.last?.text.contains("ASTER_REMOTE_OK") == true, "Live remote task must return the requested marker")
            print("PASS LIVE: encrypted phone request → local relay → Mac store → OpenAI → confirmed task result; isolated fixture; hosted session cleaned up.")
        }
        print("PASS: private pairing, TLS enforcement, authenticated encryption, wrong-key/tamper/reflection/replay/expiry rejection, durable claims, real WebSocket transport, six-agent snapshot, actual store routing, duplicate delivery, reconnect and invalid-agent rejection. No native input or private data.")
    }
}
