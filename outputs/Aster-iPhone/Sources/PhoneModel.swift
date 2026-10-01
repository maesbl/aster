import Foundation
import SwiftUI
import Combine
import UIKit

@MainActor final class PhoneModel: ObservableObject {
    let connection = RemoteConnection()
    @Published var pairing: RemotePairing?
    @Published var snapshot: RemoteSnapshot?
    @Published var conversation: RemoteConversation?
    @Published var frame: RemoteFrame?
    @Published var frameImage: UIImage?
    @Published var message = ""
    @Published var pending: [UUID: RemoteReceipt] = [:]
    @Published var selectedMission: UUID?
    @Published var verified = false
    @Published var now = Date()
    @Published var screenVisible = false
    @Published var lastReceipt: RemoteReceipt?
    private var lastSnapshot = Date.distantPast
    private var currentPairing: RemotePairing?
    private var tick: Task<Void, Never>?
    private var token: AnyCancellable?
    private var visible = true
    private var lastLease = Date.distantPast
    var online: Bool { verified && connection.peerOnline && now.timeIntervalSince(lastSnapshot) < 8 }
    var frameFresh: Bool { online && frame != nil && now.timeIntervalSince(frame!.time) < 4 }
    init() {
        do { if let data = try CredentialVault.read("remote-phone-pairing") { pairing = try JSONDecoder().decode(RemotePairing.self, from: data); try pairing?.validate() } }
        catch { message = error.localizedDescription }
        token = connection.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
        connection.onPacket = { [weak self] packet in self?.receive(packet) }
        connection.onPeerChange = { [weak self] online in
            guard let self else { return }; self.verified = false; self.frame = nil; self.frameImage = nil
            if online { Task { _ = await self.send(.init(operation: .snapshot), readOnly: true); _ = await self.send(.init(operation: .subscribe, missionID: self.selectedMission), readOnly: true) } }
            else if !self.pending.isEmpty { self.message = "Conexión interrumpida. Las órdenes pendientes no se repetirán automáticamente. Comprueba la actividad del Mac." }
        }
        if let data = UserDefaults.standard.data(forKey: "AsterPendingReceipts"), let saved = try? JSONDecoder().decode([RemoteReceipt].self, from: data) { pending = Dictionary(uniqueKeysWithValues: saved.suffix(50).map { ($0.id, $0) }) }
        resume()
        tick = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1)); guard let self, !Task.isCancelled else { return }
                self.now = Date()
                if self.screenVisible && self.online && self.visible && Date().timeIntervalSince(self.lastLease) > 4 {
                    self.lastLease = Date(); _ = await self.send(.init(operation: .screenStart), readOnly: true)
                }
            }
        }
    }
    func pair(_ code: String) {
        do { let candidate = try RemotePairing.parse(code); suspend(); snapshot = nil; conversation = nil; selectedMission = nil; currentPairing = candidate; message = "Comprobando el enlace con tu Mac…"; visible = true; connection.connect(candidate, role: .phone) }
        catch { message = error.localizedDescription }
    }
    func forget() {
        do { try CredentialVault.remove("remote-phone-pairing"); suspend(); pairing = nil; currentPairing = nil; snapshot = nil; conversation = nil; selectedMission = nil; pending = [:]; savePending(); message = "" }
        catch { message = error.localizedDescription }
    }
    func resume() {
        visible = true
        guard let config = currentPairing ?? pairing else { return }; currentPairing = config
        if !connection.connected { connection.connect(config, role: .phone) }
    }
    func suspend() {
        visible = false; verified = false; screenVisible = false; frame = nil; frameImage = nil; connection.disconnect()
    }
    func subscribe(_ id: UUID?) { selectedMission = id; conversation = nil; Task { _ = await send(.init(operation: .subscribe, missionID: id), readOnly: true) } }
    func showScreen(_ value: Bool) {
        screenVisible = value
        if !value { frame = nil; frameImage = nil }
        Task { lastLease = Date(); _ = await send(.init(operation: value ? .screenStart : .screenStop), readOnly: true) }
    }
    @discardableResult func send(_ command: RemoteCommand, readOnly: Bool = false) async -> Bool {
        if !readOnly && !online { message = "El Mac no está conectado. La orden no se ha enviado."; return false }
        if !readOnly {
            pending[command.id] = .init(id: command.id, status: "sending", message: "Esperando confirmación del Mac."); savePending()
        }
        do { try await connection.send(.command, command); return true }
        catch {
            if !readOnly { pending[command.id]?.status = "unconfirmed"; pending[command.id]?.message = "Sin confirmación. Consulta la actividad antes de repetirla."; savePending(); message = "No se pudo confirmar la entrega. Revisa la actividad antes de reenviar." }
            else if visible && connection.peerOnline { message = error.localizedDescription }
            return false
        }
    }
    func input(_ input: RemoteInput) { Task { _ = await send(.init(operation: .input, input: input)) } }
    private func receive(_ packet: RemotePacket) {
        do {
            switch packet.kind {
            case .snapshot:
                let value = try packet.decode(RemoteSnapshot.self)
                if let candidate = currentPairing, pairing != candidate {
                    try CredentialVault.save(JSONEncoder().encode(candidate), account: "remote-phone-pairing"); pairing = candidate; message = "Tu Mac está enlazado."
                }
                snapshot = value; lastSnapshot = Date(); now = Date(); verified = true
                for receipt in value.receipts where pending[receipt.id] != nil && receipt.status != "received" { accept(receipt) }
            case .conversation: let value = try packet.decode(RemoteConversation.self); if value.id == selectedMission { conversation = value }
            case .frame:
                guard screenVisible && visible else { return }
                let value = try packet.decode(RemoteFrame.self)
                guard value.width > 0, value.width <= 4096, value.height > 0, value.height <= 4096, value.jpeg.count < 1_300_000, let image = UIImage(data: value.jpeg) else { return }
                frame = value; frameImage = image
            case .receipt:
                accept(try packet.decode(RemoteReceipt.self))
            case .screenEnded: frame = nil; frameImage = nil
            default: break
            }
        } catch { message = "No se pudo leer la respuesta del Mac. " + error.localizedDescription }
    }
    private func accept(_ receipt: RemoteReceipt) {
        pending.removeValue(forKey: receipt.id); savePending(); lastReceipt = receipt
        if receipt.status == "error" { message = receipt.message }
        if let id = receipt.missionID { selectedMission = id }
    }
    private func savePending() { UserDefaults.standard.set(try? JSONEncoder().encode(Array(pending.values).suffix(50)), forKey: "AsterPendingReceipts") }
}
