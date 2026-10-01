import SwiftUI
import AppKit
import ServiceManagement
import CoreImage.CIFilterBuiltins

enum PortableSetup {
    static func importPreparedKey() {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Aster/.key-import")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            if try CredentialVault.read("openai-api-key") == nil {
                let value = try AgentAPI.keyFromFile(url.path)
                guard !value.isEmpty else { return }; try CredentialVault.save(Data(value.utf8), account: "openai-api-key")
            }
            try FileManager.default.removeItem(at: url)
        } catch { /* Keep the private migration file if Keychain is locked. */ }
    }
}
struct OpenAIConnectionView: View {
    @EnvironmentObject var store: AsterStore
    @State private var key = ""
    @State private var saving = false
    @State private var message = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Label("OpenAI", systemImage: "sparkle").font(.headline); Spacer(); Text(L(store.connectionStatus)).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            Text("Conecta tu cuenta para que los agentes puedan pensar, hablar y trabajar. La clave queda en el Llavero de este Mac.").font(.caption).foregroundStyle(.secondary)
            HStack {
                SecureField("Clave de API de OpenAI", text: $key).textFieldStyle(.roundedBorder)
                Button(saving ? "Comprobando…" : "Conectar") { connect(key) }.disabled(saving || key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            HStack {
                Button("Importar mi configuración") {
                    let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.showsHiddenFiles = true; panel.message = "Selecciona tu archivo de configuración de OpenAI. Solo se importa la clave al Llavero."
                    if panel.runModal() == .OK, let url = panel.url { do { connect(try AgentAPI.keyFromFile(url.path)) } catch { message = error.localizedDescription } }
                }.disabled(saving)
                Button("Comprobar conexión", action: store.refreshConnection).disabled(store.checkingConnection || saving)
                Spacer(); Link("Obtener mi clave", destination: URL(string: "https://platform.openai.com/api-keys")!)
            }.font(.caption)
            if !message.isEmpty { Text(message).font(.caption).textSelection(.enabled) }
            Text("Cada Mac utiliza su propia configuración. Tu clave no se incluye en el instalador ni se envía al iPhone. Las respuestas y la voz usan el saldo de tu cuenta de OpenAI.").font(.caption2).foregroundStyle(.secondary)
        }.padding(20).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 20))
    }
    private func connect(_ candidate: String) {
        guard !saving else { return }; saving = true; message = ""
        Task {
            do {
                let value = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                let models = try await AgentAPI(apiKey: value).availableModels()
                guard !models.isEmpty else { throw AsterError.message("La cuenta no devuelve ningún modelo disponible.") }
                try CredentialVault.save(Data(value.utf8), account: "openai-api-key")
                key = ""; message = "Conexión guardada en el Llavero."; store.refreshConnection()
            } catch { message = error.localizedDescription }
            saving = false
        }
    }
}
struct RemoteSettingsView: View {
    @ObservedObject var remote: MacRemoteBridge
    @State private var relay = ""
    @State private var reveal = false
    @State private var confirmRevoke = false
    @State private var loginMessage = ""
    private var qr: NSImage? {
        guard let code = remote.pairing?.code else { return nil }
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(code.utf8); filter.correctionLevel = "M"
        guard let result = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 5, y: 5)), let cg = CIContext().createCGImage(result, from: result.extent) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Label("Tu Mac, desde tu iPhone", systemImage: "iphone.and.arrow.forward").font(.headline); Spacer(); Circle().fill(remote.connection.peerOnline ? Color.green : Color.secondary.opacity(0.4)).frame(width: 7, height: 7); Text(remote.connection.status).font(.caption).foregroundStyle(.secondary) }
            Text("Habla con tus agentes, sigue sus tareas y abre la pantalla del Mac estés donde estés. El Mac necesita Internet, Aster abierto y la sesión iniciada.").font(.caption).foregroundStyle(.secondary)
            if remote.pairing == nil {
                TextField("Servidor de enlace · wss://…", text: $relay).textFieldStyle(.roundedBorder)
                HStack { Button("Crear enlace privado") { remote.createPairing(relay: relay); reveal = remote.pairing != nil }.disabled(relay.isEmpty); Text("La dirección la proporciona quien despliega Aster Relay.").font(.caption2).foregroundStyle(.secondary) }
            } else {
                Toggle("Disponible para mi iPhone", isOn: Binding(get: { remote.enabled }, set: { $0 ? remote.start() : remote.stop() })).toggleStyle(.switch)
                Toggle("Permitir controlar este Mac", isOn: $remote.allowControl).toggleStyle(.switch)
                Text("Permite que tu iPhone inicie tareas en pantalla y use el control manual. Puedes desactivarlo aquí en cualquier momento.").font(.caption2).foregroundStyle(.secondary)
                if remote.sharing { Label("Tu iPhone está viendo esta pantalla", systemImage: "rectangle.inset.filled.and.person.filled").font(.caption).foregroundStyle(.green) }
                HStack { Button(reveal ? "Ocultar código" : "Enlazar mi iPhone") { withAnimation(.easeInOut(duration: 0.2)) { reveal.toggle() } }; Button("Desvincular iPhone", role: .destructive) { confirmRevoke = true } }
                if reveal, let qr {
                    HStack(alignment: .center, spacing: 20) {
                        Image(nsImage: qr).interpolation(.none).resizable().scaledToFit().frame(width: 205, height: 205).padding(12).background(.white, in: RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 12) {
                            Text("1. Abre Aster Remote en tu iPhone.\n2. Pulsa «Escanear el código».\n3. Apunta a este código para enlazar.").font(.callout).lineSpacing(7)
                            Button("Copiar enlace") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(remote.pairing!.code, forType: .string) }
                            Text("Este código da acceso a tu Aster. Guárdalo para ti. Desvincular lo invalida.").font(.caption2).foregroundStyle(.secondary)
                        }
                    }.transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            if !remote.error.isEmpty { Text(remote.error).font(.caption).foregroundStyle(.orange) }
            Divider()
            HStack {
                Button("Abrir Aster al iniciar sesión") {
                    do { try SMAppService.mainApp.register(); loginMessage = "Inicio de sesión configurado. Revisa Ítems de inicio si macOS solicita confirmación." }
                    catch { loginMessage = error.localizedDescription }
                }
                Button("Ajustes de inicio") { SMAppService.openSystemSettingsLoginItems() }
            }.font(.caption)
            if !loginMessage.isEmpty { Text(loginMessage).font(.caption2).foregroundStyle(.secondary) }
            Text("Mientras el acceso remoto está activo, Aster evita el reposo por inactividad. Cerrar la tapa, apagar el Mac o perder Internet interrumpe la conexión. Bloquearlo detiene la pantalla y el control.").font(.caption2).foregroundStyle(.secondary)
        }.padding(20).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 20))
        .confirmationDialog("¿Desvincular el iPhone? Tendrás que escanear un código nuevo para volver a conectarlo.", isPresented: $confirmRevoke) { Button("Desvincular", role: .destructive) { remote.revoke(); reveal = false } }
    }
}
