import Foundation

@main struct CompanionTests {
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) { if !condition() { fatalError(message) } }
    @MainActor static func main() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("aster-companion-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = AsterStore(directory: folder, startServices: false, apiFactory: { throw AsterError.message("Connection fixture") })
        var first = Mission(title: "Atlas homework", specialistID: "study"); first.messages = [.init(role: "assistant", text: "")]
        var second = Mission(title: "Nova document", specialistID: "builder"); second.messages = [.init(role: "assistant", text: "")]
        store.state.missions = [first, second]; store.startWork(first.id); store.startWork(second.id)
        store.handle(.text("same-item-id", "ATLAS", false), id: first.id)
        store.handle(.text("same-item-id", "NOVA", false), id: second.id)
        store.handle(.text("same-item-id", "_ONLY", false), id: first.id)
        store.handle(.session("session-nova"), id: second.id); store.handle(.session("session-atlas"), id: first.id)
        store.handle(.turn("turn-a"), id: first.id); store.handle(.turn("turn-b"), id: second.id)
        store.setActivity("Independent status", for: second.id)
        try await Task.sleep(for: .milliseconds(110))
        check(store.state.missions[0].messages.last?.text == "ATLAS_ONLY" && store.state.missions[1].messages.last?.text == "NOVA", "Interleaved equal item IDs must not mix transcripts")
        check(store.state.missions[0].sessionID == "session-atlas" && store.state.missions[1].turnID == "turn-b", "Turn and session identities belong to their own task")
        store.finishWork(first.id)
        check(!store.isRunning(first.id) && store.isRunning(second.id) && store.activity(for: second.id) == "Independent status", "Finishing one task must preserve the other's runtime and status")
        store.handle(.text("same-item-id", "_CONTINUES", false), id: second.id)
        store.handle(.text("same-item-id", "LATE_EVENT", false), id: first.id)
        store.finishWork(second.id)
        check(store.state.missions[0].messages.last?.text == "ATLAS_ONLY" && store.state.missions[1].messages.last?.text == "NOVA_CONTINUES", "Late completed-task events must not overwrite results")
        store.state.preferences.parallelMissions = 2
        check(store.sendDesktop("Parallel study", agentID: "study"), "First agent starts")
        check(!store.sendDesktop("Double submission", agentID: "study"), "Same conversation cannot overlap")
        check(store.sendDesktop("Parallel build", agentID: "builder"), "A separate agent can work concurrently")
        check(!store.sendDesktop("Beyond capacity", agentID: "personal") && store.desktopMission(for: "personal") == nil, "Capacity rejects without creating a phantom task")
        for _ in 0..<100 where store.busy { try await Task.sleep(for: .milliseconds(10)) }
        check(!store.busy, "Independent failures release all task slots")
        var routine = AgentRoutine(); routine.title = "Routine fixture"; routine.instruction = "Prepare a local draft"; routine.enabled = true
        routine.timeZone = "America/New_York"; routine.hour = 2; routine.minute = 30
        let iso = ISO8601DateFormatter()
        let next = routine.next(after: iso.date(from: "2026-03-08T06:59:00Z")!)
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: routine.timeZone)!
        check(calendar.component(.day, from: next) == 8 && next > iso.date(from: "2026-03-08T06:59:00Z")!, "DST missing local time advances to a valid same-day time")
        routine.cadence = "weekdays"; let monday = routine.next(after: iso.date(from: "2026-10-02T23:00:00Z")!)
        check(calendar.component(.weekday, from: monday) == 2, "Weekday routine skips weekends in its own zone")
        store.saveRoutine(routine); store.selectedMission = first.id; store.page = "Personajes"
        check(store.runRoutine(routine.id), "Manual routine starts")
        let claim = store.state.routines[0].lastMissionID!
        check(store.selectedMission == first.id && store.page == "Personajes", "Background work never steals navigation")
        let onDisk = try JSONDecoder().decode(SavedState.self, from: Data(contentsOf: folder.appendingPathComponent("state.json")))
        check(onDisk.routines[0].lastMissionID == claim && onDisk.missions.first(where: { $0.id == claim })?.status == "Preparada", "Routine claim is durable before network submission")
        check(!store.runRoutine(routine.id), "A routine cannot double-dispatch its current run")
        for _ in 0..<100 where store.busy { try await Task.sleep(for: .milliseconds(10)) }
        check(!store.state.routines[0].enabled, "Failed routines pause instead of looping API retries")
        let mi = store.state.missions.firstIndex(where: { $0.id == claim })!; store.state.missions[mi].status = "Por recuperar"
        check(!store.runRoutine(routine.id), "An uncertain run must be reconciled before another dispatch")
        let legacy = try JSONDecoder().decode(SavedState.self, from: Data("{}".utf8)); check(legacy.routines.isEmpty && legacy.preferences.parallelMissions == nil, "Legacy state retains defaults")
        let geometry = ScreenGeometry(displayID: 9, frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080), imageWidth: 1600, imageHeight: 900)
        var action = DesktopAction(action: "drag", explanation: "Draw the requested line", path: [.init(x: 10, y: 10), .init(x: 1500, y: 800)])
        try action.validate(geometry: geometry, active: true)
        action.path = [.init(x: 10, y: 10), .init(x: 1600, y: 10)]
        do { try action.validate(geometry: geometry, active: true); fatalError("Offscreen drag should fail") } catch {}
        let valid = CoachAnswer(answer: "This is a teaching annotation", marks: [.init(kind: "arrow", points: [.init(x: 0.1, y: 0.2), .init(x: 0.4, y: 0.5)], label: "Target")]); try valid.validate()
        for mark in [ScreenMark(kind: "arrow", points: [.init(x: -0.1, y: 0)], label: ""), ScreenMark(kind: "line", points: [.init(x: .nan, y: 0), .init(x: 0, y: 0)], label: ""), ScreenMark(kind: "execute", points: [.init(x: 0, y: 0)], label: "")] {
            do { try mark.validate(); fatalError("Invalid marks must be rejected") } catch {}
        }
        do { _ = try CoachAnswer.decode(["status": "incomplete", "output": []]); fatalError("Incomplete model responses are not success") } catch {}
        print("PASS: parallel streams and identities, late-event isolation, independent completion, capacity, routine durable claims/no replay/failure pause, background focus, DST/weekdays, legacy state, bounded drawing and screen annotation validation. No network or native input.")
    }
}
