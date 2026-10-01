import Foundation

@main struct ServicesTests {
    static func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
    @MainActor static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("aster-services-" + UUID().uuidString); try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true); defer { try? FileManager.default.removeItem(at: root) }
        let store = AsterStore(directory: root, startServices: false); let mission = Mission(title: "Sources fixture", specialistID: "personal"); store.state.missions = [mission]
        let call = PendingToolCall(turnID: "turn", callID: "alert-call", name: "aster_notify", arguments: ["text": "Entregar la tarea", "date": Date().addingTimeInterval(3600).formatted(.iso8601), "recurrence": "daily"])
        let result = try await store.handleTool("session", call: call, missionID: mission.id); let again = try await store.handleTool("session", call: call, missionID: mission.id)
        let object = try JSONSerialization.jsonObject(with: Data(result.utf8)) as! [String: Any]
        check(result == again && store.state.alerts.count == 1 && object["scheduled"] as? Bool == false && object["needs_notification_permission"] as? Bool == true, "Notify is idempotent and does not invent a macOS permission")
        let restored = AsterStore(directory: root, startServices: false); let recovered = try await restored.handleTool("session", call: call, missionID: mission.id)
        check(recovered == result && restored.state.alerts.count == 1, "Notification identity survives restart")
        for name in ["aster_mail", "aster_calendar", "aster_reminders", "aster_health"] {
            do { _ = try await store.handleTool("session", call: .init(turnID: "turn", callID: name, name: name, arguments: ["operation": "latest"]), missionID: mission.id); fatalError("Unconnected source must not return invented content") } catch { check(!error.localizedDescription.isEmpty, "Source error must be actionable") }
        }
        let xml = root.appendingPathComponent("health.xml")
        try """
        <?xml version="1.0"?><HealthData><Record type="HKQuantityTypeIdentifierBodyMass" value="70" unit="kg" sourceName="Fixture" endDate="2026-09-28 09:00:00 -0600"/><Record type="HKQuantityTypeIdentifierBodyMass" value="71" unit="kg" sourceName="Fixture" endDate="2026-09-29 09:00:00 -0600"/><Record type="HKQuantityTypeIdentifierStepCount" value="50" unit="count" sourceName="Fixture" endDate="2026-09-29 08:00:00 -0600"/></HealthData>
        """.write(to: xml, atomically: true, encoding: .utf8)
        let snapshot = try HealthExportReader.read(xml); store.state.health = snapshot
        let health = try await store.handleTool("session", call: .init(turnID: "turn", callID: "health-present", name: "aster_health", arguments: [:]), missionID: mission.id)
        check(snapshot.recordCount == 3 && snapshot.metrics.count == 2 && snapshot.metrics.first { $0.id.contains("BodyMass") }?.value == "71" && health.contains("\"live\":false"), "Health import preserves latest source records, units and dates without claiming live access or daily totals")
        let empty = root.appendingPathComponent("empty.xml"); try "<HealthData/>".write(to: empty, atomically: true, encoding: .utf8)
        do { _ = try HealthExportReader.read(empty); fatalError("Invalid Health export should fail") } catch {}
        check(AsterStore.parseDate("2026-09-30T17:00:00-06:00") != nil && AsterStore.parseDate("mañana") == nil, "Reminder time accepts explicit timezone and rejects ambiguous parser input")
        print("PASS: source connection gates, honest pending notifications, durable notification deduplication, Apple Health record parsing and timestamps, explicit reminder time zones. No personal source or native notification permission was accessed.")
    }
}
