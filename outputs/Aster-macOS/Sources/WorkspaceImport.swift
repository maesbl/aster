import AppKit
import Foundation

extension AsterStore {
    func importWorkspace() {
        guard !busy, !computer.active else { notice = "Termina o detén las tareas antes de restaurar una copia."; return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false; panel.allowedContentTypes = [.json]
        panel.message = "Elige una copia de Aster. Se conservará una copia de los datos actuales antes de restaurarla."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 30_000_000 else { throw AsterError.message("La copia supera los 30 MB permitidos.") }
            var imported = try JSONDecoder().decode(SavedState.self, from: Data(contentsOf: url))
            guard !imported.specialists.isEmpty, Set(imported.missions.map(\.id)).count == imported.missions.count else { throw AsterError.message("La copia tiene datos incompletos o conversaciones duplicadas.") }
            let alert = NSAlert(); alert.messageText = "Restaurar esta copia de Aster"
            alert.informativeText = "Contiene \(imported.missions.count) conversaciones y \(imported.companies.count) empresas. Sustituirá los datos actuales; se guardará una copia antes de hacerlo. Las conexiones y rutinas se activan de nuevo en este Mac."
            alert.addButton(withTitle: "Restaurar"); alert.addButton(withTitle: "Cancelar")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Aster/Backups")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let backup = directory.appendingPathComponent("antes-de-restaurar-\(UUID().uuidString).json")
            try JSONEncoder().encode(state).write(to: backup, options: .atomic); try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
            imported.preferences.autonomous = false; imported.preferences.watchMail = false; imported.preferences.watchCalendar = false; imported.preferences.watchReminders = false; imported.preferences.notifications = false
            for index in imported.routines.indices { imported.routines[index].enabled = false }
            for index in imported.missions.indices where ["Trabajando", "Cancelación pendiente", "Preparada"].contains(imported.missions[index].status) { imported.missions[index].status = "Por recuperar" }
            let previous = state; state = imported
            do { try persistToolState() } catch { state = previous; throw error }
            selectedMission = nil; artifacts = []; attachments = []; calendarStatus = "Sin conectar"; mailStatus = "Sin conectar"; remindersStatus = "Sin conectar"; reminders = []
            save(); refreshConnection(); notice = "Copia restaurada. Revisa las conexiones y activa las rutinas que quieras usar en este Mac."
        } catch { notice = "No se ha restaurado la copia: " + error.localizedDescription }
    }
}
