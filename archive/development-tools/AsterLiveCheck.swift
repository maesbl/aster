import Foundation

@main struct AsterLiveCheck {
    static func log(_ value: String) { FileHandle.standardOutput.write(Data((value + "\n").utf8)) }
    @MainActor static func main() async throws {
        let workspace = URL(fileURLWithPath: "/Users/mescu/Documents/Codex/2026-09-30/i-w")
        let testDirectory = workspace.appendingPathComponent("work/aster-native-validation")
        let store = AsterStore(directory: testDirectory, startServices: false)
        var settings = IntelligenceSettings(); settings.webSearch = false; settings.effort = "low"; settings.responseLanguage = "ca"; settings.maxAgents = 2
        store.settings = settings
        let mission = Mission(title: "Primer plan de Aster", specialistID: "director")
        store.state.missions = [mission]; store.save()
        let file = Attachment(name: "aster-context.txt", data: Data("Aster es una app nativa para macOS con personajes minimalistas animados, un compañero personal y especialistas que ayudan a pensar, crear y desarrollar empresas. La experiencia debe ser clara, fluida y personal. INPUT_VERIFIED_ASTER_2026".utf8))
        let api = try AgentAPI(environmentFile: workspace.appendingPathComponent(".env.local").path)
        var sid: String?; var tid: String?; var events = 0; var toolCalls = 0; var text = ""
        let started = Date()
        do {
            try await api.run(sessionID: nil, specialist: store.agent, settings: settings,
                input: "Read the input file at \(file.path) and verify its marker. Ask two subagents for independent short opinions: one proposes Aster's value proposition and one proposes a clear daily user experience. Wait for both. In Catalan, combine the ideas into a useful first plan under 300 words. Create /workspace/outputs/aster-primer-plan.md containing the plan and the exact marker INPUT_VERIFIED_ASTER_2026 from the input. Inspect the file to verify it. Use aster_create_task exactly once to save Definir la proposta de valor d’Aster. End your reply with a brief truthful verification. Do not browse the web or create additional tasks.", attachments: [file],
                toolHandler: { session, call in toolCalls += 1; return try await store.handleTool(session, call: call, missionID: mission.id) },
                handler: { event in
                    events += 1
                    switch event {
                    case .session(let id): sid = id; store.state.missions[0].sessionID = id; store.save(); log("Native hosted session created.")
                    case .turn(let id): tid = id; store.state.missions[0].turnID = id; store.save()
                    case .text(_, let value, let complete): if complete { text = value }
                    case .activity(let value): log(value)
                    default: break
                    }
                })
            guard let sid else { throw AsterError.message("No session ID") }
            let result = try await api.recover(sid, turnID: tid)
            guard result.0 == "completed", !result.1.isEmpty else { throw AsterError.message("No completed native response") }
            let workersPage = try await api.json("/\(sid)/subagents?limit=100")
            let workers = workersPage["data"] as? [[String: Any]] ?? []
            var completedWorkers = 0
            for worker in workers {
                guard let workerID = worker["id"] as? String else { continue }
                let history = try await api.json("/\(sid)/subagents/\(workerID)/turns?limit=100")
                if (history["data"] as? [[String: Any]] ?? []).contains(where: { $0["status"] as? String == "completed" }) { completedWorkers += 1 }
            }
            let artifacts = try await api.artifacts(sid, turnID: tid)
            guard let artifact = artifacts.first(where: { $0.path.hasSuffix("aster-primer-plan.md") }) else { throw AsterError.message("Missing native artifact") }
            let destination = workspace.appendingPathComponent("outputs/Aster-primer-plan.md")
            try await api.download(artifact, sessionID: sid, destination: destination)
            let content = try String(contentsOf: destination, encoding: .utf8)
            guard content.contains("INPUT_VERIFIED_ASTER_2026"), store.state.tasks.count == 1, toolCalls > 0, completedWorkers >= 2, tid != nil else { throw AsterError.message("An end-to-end check did not pass") }
            let report: [String: Any] = ["completed": true, "response": result.1, "tool_calls": toolCalls, "local_tasks": store.state.tasks.count, "completed_subagents": completedWorkers, "root_turn_id_saved": tid != nil, "attachment_verified": true, "artifact_verified": true, "events": events, "elapsed_seconds": Date().timeIntervalSince(started)]
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: workspace.appendingPathComponent("work/aster-native-live-report.json"))
            try await api.deleteSession(sid)
            log("PASS: native Swift streaming, Catalan response, two completed specialists, attachment read, durable local function result, one saved task, artifact download and verified file contents. Test session deleted.")
        } catch {
            if let sid { try? await api.cancel(sid); try? await api.deleteSession(sid) }
            throw error
        }
    }
}
