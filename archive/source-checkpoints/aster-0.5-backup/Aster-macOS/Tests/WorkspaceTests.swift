import Foundation

@main struct WorkspaceTests {
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) { if !condition() { fatalError(message) } }
    @MainActor static func main() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("aster-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        var original = SavedState()
        original.specialists[0].name = "Mi Aster"
        original.companies = [.init(name: "Empresa anterior", goal: "Conservar contexto", notes: "Información anterior")]
        original.missions = [.init(title: "Misión anterior", specialistID: "director", messages: [.init(role: "user", text: "Una idea")], sessionID: "saved-session", turnID: "saved-turn", status: "Trabajando")]
        let oldKeys = ["specialists", "companies", "missions", "inbox", "preferences"]
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as! [String: Any]
        let legacy = Dictionary(uniqueKeysWithValues: oldKeys.map { ($0, json[$0]!) })
        try JSONSerialization.data(withJSONObject: legacy).write(to: temp.appendingPathComponent("state.json"))
        let store = AsterStore(directory: temp, startServices: false)
        check(store.state.specialists[0].name == "Mi Aster" && store.state.companies[0].notes == "Información anterior", "Legacy data must survive migration")
        check(store.state.missions[0].sessionID == "saved-session" && store.state.missions[0].status == "Por recuperar", "Interrupted mission must retain remote identity")
        check(store.state.tasks.isEmpty && store.state.memories.isEmpty, "Missing new collections default safely")
        check(!store.settings.shareSources && !store.settings.automaticMemory, "Source sharing and memory writing default off")
        let mid = store.state.missions[0].id
        let call = PendingToolCall(turnID: "turn-local", callID: "call-1", name: "aster_create_task", arguments: ["title": "Preparar la propuesta"])
        let result = try store.performTool("session-local", call: call, missionID: mid)
        let again = try store.performTool("session-local", call: call, missionID: mid)
        check(result == again && store.state.tasks.count == 1 && store.state.toolReceipts.count == 1, "A repeated pending call must not create duplicate tasks")
        let reloaded = AsterStore(directory: temp, startServices: false)
        let persisted = try reloaded.performTool("session-local", call: call, missionID: mid)
        check(persisted == result, "Tool receipt must survive app restart")
        check(reloaded.state.tasks.count == 1, "Restart preserves the same local task")
        let sources = try store.performTool("session-local", call: .init(turnID: "turn-local", callID: "call-sources", name: "aster_workspace", arguments: ["query": "sources"]), missionID: mid)
        check(sources.contains("false") && sources.contains("[]"), "Private sources must not be returned without opt-in")
        do { _ = try store.performTool("session-local", call: .init(turnID: "turn-local", callID: "call-memory", name: "aster_remember", arguments: ["text": "Una preferencia"]), missionID: mid); fatalError("Memory mutation must require opt-in") } catch {}
        var settings = store.settings; settings.automaticMemory = true; store.settings = settings
        _ = try store.performTool("session-local", call: .init(turnID: "turn-local", callID: "call-memory-enabled", name: "aster_remember", arguments: ["text": "Prefiero propuestas breves"]), missionID: mid)
        check(store.state.memories.count == 1, "Enabled memory tool persists a requested preference")
        let signature = AgentAPI.signature(for: store.agent, settings: store.settings)
        settings.webSearch.toggle()
        check(signature != AgentAPI.signature(for: store.agent, settings: settings), "Changed tool settings require a new remote configuration")
        var company = store.state.companies[0]; company.goal = "Nuevo objetivo"; store.updateCompany(company)
        store.archiveCompany(company.id); check(store.companies.isEmpty, "Company archive hides it from active work")
        store.archiveCompany(company.id, archived: false); check(store.companies[0].goal == "Nuevo objetivo", "Restore retains edited company context")
        store.renameMission(mid, title: "Nombre cambiado"); store.pinMission(mid); store.archiveMission(mid, archived: true)
        check(store.state.missions[0].title == "Nombre cambiado" && store.state.missions[0].pinned == true && store.state.missions[0].archived == true, "Mission organization must persist")
        store.state.missions[0].status = "Por recuperar"; store.selectedMission = mid
        check(!store.run("No reenviar hasta recuperar"), "Interrupted remote work must not accept duplicate input")
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: -7 * 3600)!
        func date(_ hour: Int) -> Date { calendar.date(from: .init(year: 2026, month: 9, day: 30, hour: hour))! }
        var pref = Preferences(); pref.autonomous = true; pref.quietHours = true; pref.quietStart = 23; pref.quietEnd = 7
        check(!AutonomyPolicy.canRun(preferences: pref, now: date(1), busy: false, calendar: calendar), "Quiet hours wrap across midnight")
        check(AutonomyPolicy.canRun(preferences: pref, now: date(8), busy: false, calendar: calendar), "Resume after quiet hours")
        pref.dailyRuns = pref.dailyLimit; check(!AutonomyPolicy.canRun(preferences: pref, now: date(8), busy: false, calendar: calendar), "Respect daily limits")
        pref.dailyRuns = 0; check(!AutonomyPolicy.canRun(preferences: pref, now: date(8), busy: true, calendar: calendar), "Do not overlap root missions")
        pref.lastAutonomous = date(7); check(!AutonomyPolicy.canRun(preferences: pref, now: date(8), busy: false, calendar: calendar), "Respect persistent run interval")
        check(AutonomyPolicy.dayStamp(date(23), calendar: calendar) == "2026-09-30", "Daily counter uses local calendar day")
        let blocks = MessageBlock.parse("# Resultado\nUn párrafo.\n```swift\nlet x = 1\n```\nFinal")
        check(blocks.count == 4 && blocks[2].text == "let x = 1", "Markdown code and headings retain exact content")
        let unfinished = MessageBlock.parse("```js\nconst x = 1;")
        check(unfinished.count == 1 && unfinished[0].text == "const x = 1;", "Partial streamed code remains readable")
        print("PASS: legacy migration, restart recovery, durable tool receipts, local tasks, memory permissions, source sharing, configuration changes, reversible archiving, duplicate input protection, quiet hours, daily limits and Markdown streaming.")
    }
}
