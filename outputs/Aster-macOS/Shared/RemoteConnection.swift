import Foundation
import Combine

@MainActor final class RemoteConnection: ObservableObject {
    @Published private(set) var status = "Desconectado"
    @Published private(set) var connected = false
    @Published private(set) var peerOnline = false
    var onPacket: ((RemotePacket) async -> Void)?
    var onPeerChange: ((Bool) -> Void)?
    private var socket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var job: Task<Void, Never>?
    private var ping: Task<Void, Never>?
    private var cipher: RemoteCipher?
    private var generation = UUID()
    private(set) var pairing: RemotePairing?
    func connect(_ pairing: RemotePairing, role: RemoteRole) {
        disconnect(); self.pairing = pairing; cipher = RemoteCipher(pairing: pairing, role: role)
        let token = generation
        job = Task { [weak self] in
            var attempt = 0
            while !Task.isCancelled {
                guard let self, self.generation == token else { return }
                do {
                    try pairing.validate()
                    self.status = attempt == 0 ? "Conectando…" : "Reconectando…"
                    var request = URLRequest(url: URL(string: pairing.relay.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/v1/connect")!)
                    request.setValue("Bearer " + pairing.relayToken, forHTTPHeaderField: "Authorization")
                    request.setValue(pairing.room, forHTTPHeaderField: "X-Aster-Room"); request.setValue(role.rawValue, forHTTPHeaderField: "X-Aster-Role")
                    request.timeoutInterval = 20
                    let config = URLSessionConfiguration.ephemeral; config.waitsForConnectivity = false
                    let session = URLSession(configuration: config); self.session = session
                    let socket = session.webSocketTask(with: request); socket.maximumMessageSize = 2_000_000; self.socket = socket; socket.resume()
                    self.ping = Task { [weak socket] in
                        while !Task.isCancelled {
                            try? await Task.sleep(for: .seconds(15)); guard !Task.isCancelled, let socket else { return }
                            socket.sendPing { error in if error != nil { socket.cancel(with: .goingAway, reason: nil) } }
                        }
                    }
                    while !Task.isCancelled {
                        let message = try await socket.receive(); guard self.generation == token else { return }
                        switch message {
                        case .data(let data):
                            let packet = try self.cipher!.open(data); attempt = 0
                            self.connected = true; self.status = "Conectado"
                            await self.onPacket?(packet)
                        case .string(let text):
                            guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any], object["type"] as? String == "presence", let online = object["online"] as? Bool else { continue }
                            self.connected = true; self.peerOnline = online
                            self.status = online ? "Dispositivo conectado" : (role == .phone ? "Esperando al Mac" : "Esperando al iPhone")
                            self.onPeerChange?(online)
                        @unknown default: break
                        }
                    }
                } catch {
                    guard self.generation == token, !Task.isCancelled else { return }
                    self.status = "Sin conexión · reintentando"; self.connected = false; self.peerOnline = false; self.onPeerChange?(false)
                }
                self.ping?.cancel(); self.socket?.cancel(with: .goingAway, reason: nil); self.session?.invalidateAndCancel()
                attempt += 1
                try? await Task.sleep(for: .seconds(min(20, pow(1.7, Double(min(attempt, 7)))) + Double.random(in: 0...0.7)))
            }
        }
    }
    func send<T: Encodable>(_ kind: RemoteKind, _ payload: T) async throws {
        guard connected, peerOnline, let socket, let cipher else { throw RemoteError.message("El otro dispositivo no está conectado. La orden no se ha enviado.") }
        let packet = try RemotePacket(kind, payload)
        try await socket.send(.data(cipher.seal(packet)))
    }
    func disconnect() {
        generation = UUID(); job?.cancel(); job = nil; ping?.cancel(); ping = nil
        socket?.cancel(with: .normalClosure, reason: nil); socket = nil; session?.invalidateAndCancel(); session = nil
        connected = false; peerOnline = false; status = "Desconectado"; onPeerChange?(false)
    }
}
