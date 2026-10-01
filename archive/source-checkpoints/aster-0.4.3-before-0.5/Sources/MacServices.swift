import AppKit
import EventKit
import UserNotifications
import CryptoKit

enum AppleMailReader {
    private static func script(_ source: String) throws -> NSAppleEventDescriptor {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { throw AsterError.message("No se ha podido preparar la consulta de Mail.") }
        let result = script.executeAndReturnError(&error)
        guard error == nil else { throw AsterError.message("Mail necesita autorización. Conecta Apple Mail en Ajustes y acepta el permiso de macOS.") }
        return result
    }
    static func read(operation: String, query: String = "", messageID: String = "", limit: Int = 5) async throws -> [MailItem] {
        try await Task.detached(priority: .userInitiated) {
            if operation == "read" {
                guard let id = Int(messageID), id >= 0 else { throw AsterError.message("Identificador de correo no válido.") }
                let item = try script("""
                tell application "Mail"
                    set candidates to messages of inbox whose id is \(id)
                    if (count of candidates) is 0 then return {}
                    set m to item 1 of candidates
                    return {id of m, subject of m as text, sender of m as text, date received of m, content of m as text}
                end tell
                """)
                guard item.numberOfItems >= 5 else { return [] }
                return [MailItem(id: String(item.atIndex(1)?.int32Value ?? 0), subject: item.atIndex(2)?.stringValue ?? "", sender: item.atIndex(3)?.stringValue ?? "", received: item.atIndex(4)?.dateValue ?? .distantPast, body: String((item.atIndex(5)?.stringValue ?? "").prefix(30000)))]
            }
            let headers = try script("""
            tell application "Mail"
                return {id of messages of inbox, subject of messages of inbox, sender of messages of inbox, date received of messages of inbox}
            end tell
            """)
            guard let ids = headers.atIndex(1), let subjects = headers.atIndex(2), let senders = headers.atIndex(3), let dates = headers.atIndex(4) else { return [] }
            var messages: [MailItem] = []
            for i in 1...max(1, ids.numberOfItems) where i <= ids.numberOfItems {
                let subject = subjects.atIndex(i)?.stringValue ?? "", sender = senders.atIndex(i)?.stringValue ?? ""
                if query.isEmpty || subject.localizedCaseInsensitiveContains(query) || sender.localizedCaseInsensitiveContains(query) {
                    messages.append(.init(id: String(ids.atIndex(i)?.int32Value ?? 0), subject: subject, sender: sender, received: dates.atIndex(i)?.dateValue ?? .distantPast))
                }
            }
            let ordered = messages.sorted { $0.received > $1.received }
            if operation == "latest", let latest = ordered.first {
                return try await read(operation: "read", messageID: latest.id, limit: 1)
            }
            return Array(ordered.prefix(min(20, max(1, limit))))
        }.value
    }
}

extension AsterStore {
    func disableNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        state.preferences.notifications = false
        for index in state.alerts.indices { state.alerts[index].scheduled = false }; save()
    }
    func addAlert(text: String, date: Date, recurrence: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Task {
            do {
                var alert = ScheduledAlert(text: text, date: date, recurrence: recurrence)
                if state.preferences.notifications { try await scheduleAlert(alert); alert.scheduled = true }
                state.alerts.append(alert); save()
                if !alert.scheduled { notice = "Aviso guardado. Activa las notificaciones para que macOS lo entregue a la hora elegida." }
            } catch { notice = error.localizedDescription }
        }
    }
    func connectReminders() {
        Task {
            do { state.preferences.watchReminders = try await calendar.requestFullAccessToReminders(); remindersStatus = state.preferences.watchReminders == true ? "Conectado" : "Permiso denegado"; save(); if state.preferences.watchReminders == true { await refreshReminders() } }
            catch { remindersStatus = error.localizedDescription }
        }
    }
    func fetchReminders() async throws -> [EKReminder] {
        guard state.preferences.watchReminders == true, EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { throw AsterError.message("Conecta Recordatorios de Apple en Ajustes y permite el acceso de macOS.") }
        let predicate = calendar.predicateForReminders(in: nil)
        return await withCheckedContinuation { continuation in calendar.fetchReminders(matching: predicate) { continuation.resume(returning: $0 ?? []) } }
    }
    func refreshReminders() async {
        do {
            let items = try await fetchReminders()
            reminders = items.map { .init(id: $0.calendarItemIdentifier, title: $0.title ?? "", notes: $0.notes ?? "", list: $0.calendar.title, completed: $0.isCompleted, due: $0.dueDateComponents.flatMap { Calendar.current.date(from: $0) }) }.sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
            remindersStatus = "Conectado"
        } catch { remindersStatus = error.localizedDescription }
    }
    func completeReminder(_ id: String) {
        Task { do { guard let reminder = calendar.calendarItem(withIdentifier: id) as? EKReminder else { return }; reminder.isCompleted.toggle(); try calendar.save(reminder, commit: true); await refreshReminders() } catch { notice = error.localizedDescription } }
    }
    func scheduleAlert(_ alert: ScheduledAlert) async throws {
        let content = UNMutableNotificationContent(); content.title = "Aster"; content.body = alert.text; content.sound = .default
        var fields: Set<Calendar.Component> = [.hour, .minute, .second]
        if alert.recurrence == "weekly" { fields.insert(.weekday) }
        if alert.recurrence == "none" { fields.formUnion([.year, .month, .day]) }
        let components = Calendar.current.dateComponents(fields, from: alert.date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: alert.recurrence != "none")
        try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: alert.id.uuidString, content: content, trigger: trigger))
    }
    func activatePendingAlerts() async {
        let pending = state.alerts.filter { !$0.scheduled && ($0.date > Date() || $0.recurrence != "none") }
        for alert in pending {
            do { try await scheduleAlert(alert); if let index = state.alerts.firstIndex(where: { $0.id == alert.id }) { state.alerts[index].scheduled = true; save() } } catch { notice = error.localizedDescription }
        }
    }
    func cancelAlert(_ id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        state.alerts.removeAll { $0.id == id }; save()
    }
    func handleTool(_ session: String, call: PendingToolCall, missionID: UUID) async throws -> String {
        if let receipt = state.toolReceipts.first(where: { $0.sessionID == session && $0.turnID == call.turnID && $0.callID == call.callID }) { return receipt.output }
        guard ["aster_mail", "aster_calendar", "aster_reminders", "aster_notify", "aster_health"].contains(call.name) else { return try performTool(session, call: call, missionID: missionID) }
        var output: [String: Any] = [:]
        switch call.name {
        case "aster_health":
            guard let health = state.health else { throw AsterError.message("Importa una exportación de Apple Salud en Conexiones. Los datos de Salud no se pueden leer directamente en este Mac.") }
            output = ["imported_at": health.imported.formatted(.iso8601), "live": false, "record_count": health.recordCount, "latest_records": health.metrics.map { ["type": $0.id, "label": $0.label, "value": $0.value, "unit": $0.unit, "date": $0.date.formatted(.iso8601), "source": $0.source] }]
        case "aster_mail":
            guard state.preferences.watchMail else { throw AsterError.message("Conecta Apple Mail en Ajustes para consultar el correo. No hace falta pegarlo en el chat.") }
            activity = "Leyendo Apple Mail"
            let items = try await AppleMailReader.read(operation: call.arguments["operation"] as? String ?? "latest", query: call.arguments["query"] as? String ?? "", messageID: call.arguments["message_id"] as? String ?? "", limit: call.arguments["limit"] as? Int ?? 5)
            output["messages"] = items.map { ["id": $0.id, "subject": $0.subject, "sender": $0.sender, "received": $0.received.formatted(.iso8601), "body": $0.body ?? ""] }
            output["source"] = "Apple Mail · inbox · live"; mailStatus = "Conectado"
        case "aster_calendar":
            guard state.preferences.watchCalendar, EKEventStore.authorizationStatus(for: .event) == .fullAccess else { throw AsterError.message("Conecta Calendarios de macOS en Ajustes y permite el acceso.") }
            let days = min(30, max(1, call.arguments["days"] as? Int ?? 1)), start = Date()
            let predicate = calendar.predicateForEvents(withStart: start, end: start.addingTimeInterval(Double(days) * 86400), calendars: nil)
            output["events"] = calendar.events(matching: predicate).sorted { $0.startDate < $1.startDate }.prefix(100).map { ["title": $0.title ?? "", "start": $0.startDate.formatted(.iso8601), "end": $0.endDate.formatted(.iso8601), "calendar": $0.calendar.title, "location": $0.location ?? ""] }
        case "aster_reminders":
            let operation = call.arguments["operation"] as? String ?? "list"
            if operation == "create" {
                guard state.preferences.watchReminders == true, EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { throw AsterError.message("Conecta Recordatorios de Apple en Ajustes.") }
                guard let title = call.arguments["title"] as? String, !title.isEmpty, let list = calendar.defaultCalendarForNewReminders() else { throw AsterError.message("Hace falta un título y una lista de Recordatorios disponible.") }
                let token = URL(string: "aster://reminder/" + Self.toolIdentity(session, call: call))!
                let existing = try await fetchReminders().first { $0.url == token }
                let reminder = existing ?? EKReminder(eventStore: calendar); reminder.title = String(title.prefix(600)); reminder.notes = call.arguments["notes"] as? String ?? ""; reminder.calendar = list; reminder.url = token
                if let value = call.arguments["due"] as? String, !value.isEmpty { guard let due = Self.parseDate(value) else { throw AsterError.message("La fecha del recordatorio no es válida.") }; reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due) }
                try calendar.save(reminder, commit: true); output = ["created": true, "id": reminder.calendarItemIdentifier, "title": reminder.title ?? ""]
            } else if operation == "complete" {
                _ = try await fetchReminders()
                guard let id = call.arguments["id"] as? String, let reminder = calendar.calendarItem(withIdentifier: id) as? EKReminder else { throw AsterError.message("No se encuentra ese recordatorio.") }
                reminder.isCompleted = true; try calendar.save(reminder, commit: true); output = ["completed": true, "id": id]
            } else {
                let items = try await fetchReminders(); let query = call.arguments["query"] as? String ?? ""
                output["reminders"] = items.filter { !$0.isCompleted && (query.isEmpty || ($0.title ?? "").localizedCaseInsensitiveContains(query)) }.prefix(100).map { ["id": $0.calendarItemIdentifier, "title": $0.title ?? "", "notes": $0.notes ?? "", "list": $0.calendar.title, "due": $0.dueDateComponents.flatMap { Calendar.current.date(from: $0) }?.formatted(.iso8601) ?? ""] }
            }
            await refreshReminders()
        case "aster_notify":
            guard let text = call.arguments["text"] as? String, !text.isEmpty, let value = call.arguments["date"] as? String, let date = Self.parseDate(value) else { throw AsterError.message("El aviso necesita un texto y una fecha ISO 8601 con zona horaria.") }
            let recurrence = call.arguments["recurrence"] as? String ?? "none"
            guard ["none", "daily", "weekly"].contains(recurrence), date > Date() || recurrence != "none" else { throw AsterError.message("La fecha del aviso debe estar en el futuro.") }
            let token = Self.toolIdentity(session, call: call)
            var alert = state.alerts.first { $0.toolKey == token } ?? ScheduledAlert(text: String(text.prefix(1000)), date: date, recurrence: recurrence, toolKey: token)
            if !state.alerts.contains(where: { $0.id == alert.id }) { state.alerts.append(alert); try persistToolState() }
            if state.preferences.notifications { try await scheduleAlert(alert); alert.scheduled = true; if let index = state.alerts.firstIndex(where: { $0.id == alert.id }) { state.alerts[index] = alert } }
            output = ["saved": true, "scheduled": alert.scheduled, "notification_id": alert.id.uuidString, "date": date.formatted(.iso8601), "needs_notification_permission": !alert.scheduled]
        default: break
        }
        let result = String(decoding: try JSONSerialization.data(withJSONObject: output, options: .sortedKeys), as: UTF8.self)
        state.toolReceipts.append(.init(sessionID: session, turnID: call.turnID, callID: call.callID, output: result)); try persistToolState(); return result
    }
    static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter(); if let date = formatter.date(from: value) { return date }; formatter.formatOptions.insert(.withFractionalSeconds); return formatter.date(from: value)
    }
    static func toolIdentity(_ session: String, call: PendingToolCall) -> String {
        SHA256.hash(data: Data((session + ":" + call.turnID + ":" + call.callID).utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
