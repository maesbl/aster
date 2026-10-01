import Foundation
@main struct LiveCompanionCheck {
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let directory = root.appendingPathComponent("work/live-companion-" + UUID().uuidString)
        let api = try AgentAPI(environmentFile: root.appendingPathComponent(".env.local").path)
        let store = AsterStore(directory: directory, startServices: false, apiFactory: { api })
        var settings = store.settings; settings.model = "gpt-6-luna"; settings.effort = "low"; settings.useMemory = false; settings.shareSources = false; settings.delegation = false; settings.webSearch = false; settings.maxMinutes = 3; store.settings = settings
        let a = store.sendDesktop("Prueba aislada. No consultes datos personales ni herramientas locales. Crea /workspace/outputs/atlas-prueba.txt con el texto ATLAS_PARALLEL_OK_56. Lee el archivo para verificarlo y responde solo con ese marcador.", agentID: "study")
        let b = store.sendDesktop("Prueba aislada. No consultes datos personales ni herramientas locales. Crea /workspace/outputs/nova-prueba.txt con el texto NOVA_PARALLEL_OK_81. Lee el archivo para verificarlo y responde solo con ese marcador.", agentID: "builder")
        guard a && b && store.activities.count == 2 else { fatalError("Parallel launch failed") }
        print("Two independent hosted sessions started from isolated test state.")
        for _ in 0..<1800 where store.busy { try await Task.sleep(for: .milliseconds(100)) }
        let missions = [store.desktopMission(for: "study")!, store.desktopMission(for: "builder")!]
        var passed = !store.busy
        for (item, expected) in zip(missions, ["ATLAS_PARALLEL_OK_56", "NOVA_PARALLEL_OK_81"]) {
            let text = item.messages.last?.text ?? ""
            let files = item.artifactRecords ?? []
            let okay = item.status == "Completada" && text.contains(expected) && !files.isEmpty
            print("\(item.specialistID): status=\(item.status), correct response=\(text.contains(expected)), artifacts=\(files.count)")
            if !okay { print("Failure: \(item.error ?? "missing output")"); passed = false }
            if let sid = item.sessionID { for file in files { try await api.download(file, sessionID: sid, destination: directory.appendingPathComponent(URL(fileURLWithPath: file.path).lastPathComponent)) }; do { _ = try await api.json("/" + sid, method: "DELETE"); print("Test session deleted.") } catch { print("Test-session cleanup could not be confirmed: " + error.localizedDescription) } }
        }
        guard missions[0].sessionID != missions[1].sessionID else { fatalError("Sessions mixed") }
        guard passed else { fatalError("Live integration failed") }
        store.flushStorage(); print("PASS: real parallel hosted sessions, isolated verified replies, downloadable files, exact completion.")
    }
}
