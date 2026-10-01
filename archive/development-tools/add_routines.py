from pathlib import Path
p=Path('outputs/Aster-macOS/Sources/Models.swift');s=p.read_text();at=s.index('struct SavedState:')
s=s[:at]+'''struct AgentRoutine: Identifiable, Codable {
    var id = UUID()
    var title = ""
    var instruction = ""
    var specialistID = "personal"
    var companyID: UUID?
    var enabled = false
    var cadence = "daily"
    var hour = 9
    var minute = 0
    var timeZone = TimeZone.current.identifier
    var nextRun = Date()
    var lastMissionID: UUID?
    var history: [UUID] = []
    func next(after now: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: timeZone) ?? .current
        var match = DateComponents(); match.hour = min(23, max(0, hour)); match.minute = min(59, max(0, minute)); match.second = 0
        var candidate = calendar.nextDate(after: now, matching: match, matchingPolicy: .nextTime, repeatedTimePolicy: .first) ?? now.addingTimeInterval(86400)
        if cadence == "weekdays" {
            while calendar.isDateInWeekend(candidate) { candidate = calendar.nextDate(after: candidate, matching: match, matchingPolicy: .nextTime, repeatedTimePolicy: .first) ?? candidate.addingTimeInterval(86400) }
        }
        return candidate
    }
}
''' +s[at:]
s=s.replace('    var health: HealthSnapshot?\n    var desktopChats', '    var health: HealthSnapshot?\n    var routines: [AgentRoutine] = []\n    var desktopChats').replace('health, desktopChats, desktopDrafts }', 'health, desktopChats, desktopDrafts, routines }').replace('        health = try c.decodeIfPresent(HealthSnapshot.self, forKey: .health)', '        health = try c.decodeIfPresent(HealthSnapshot.self, forKey: .health)\n        routines = try c.decodeIfPresent([AgentRoutine].self, forKey: .routines) ?? []')
p.write_text(s)
p=Path('outputs/Aster-macOS/Sources/Store.swift');s=p.read_text().replace('["Trabajando", "Cancelación pendiente"].contains(state.missions[index].status)', '["Trabajando", "Cancelación pendiente", "Preparada"].contains(state.missions[index].status)')
s=s.replace('private func inputContext(text: String, company: Company?, attachments: [Attachment])', 'private func inputContext(text: String, company: Company?, attachments: [Attachment], agentID: String)')
s=s.replace('if settings.useMemory { context["memory"] = memoryContext(companyID: company?.id) }', '''if settings.useMemory {
            context["memory"] = memoryContext(companyID: company?.id)
            context["recent_work"] = state.missions.filter { $0.companyID == company?.id && (company != nil || $0.specialistID == agentID) && $0.archived != true && $0.status == "Completada" }.prefix(3).map { item in
                ["title": item.title, "agent": item.specialistID, "result": String((item.messages.last(where: { $0.role == "assistant" })?.text ?? "").suffix(2000))]
            }
        }''')
s=s.replace('inputContext(text: text, company: company, attachments: attached)', 'inputContext(text: text, company: company, attachments: attached, agentID: usedAgent.id)')
s=s.replace('                let api = try makeAPI()\n                try await api.run', '                try persist()\n                let api = try makeAPI()\n                try await api.run')
s=s.replace('        guard AutonomyPolicy.canRun', '        runDueRoutines(now: now)\n        guard AutonomyPolicy.canRun')
p.write_text(s)
