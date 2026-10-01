import Foundation

@main struct DesktopChatTests {
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) { if !condition() { fatalError(message) } }
    @MainActor static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("aster-desktop-tests-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let failingAPI: () throws -> AgentAPI = { throw AsterError.message("Isolated connection failure") }
        let store = AsterStore(directory: directory, startServices: false, apiFactory: failingAPI)
        store.state.preferences.parallelMissions = 1
        let company = Company(name: "Main workspace", goal: "Keep its context")
        let original = Mission(title: "Main conversation", specialistID: "director", companyID: company.id)
        store.state.companies = [company]; store.state.missions = [original]
        store.selectedMission = original.id; store.page = "Empresas"
        store.attachments = [Attachment(name: "main-only.txt", data: Data("MAIN_ATTACHMENT".utf8))]
        store.setDesktopDraft("Draft for Atlas", agentID: "study")
        store.setDesktopDraft("Draft for Lumi", agentID: "personal")
        check(store.sendDesktop("Hello Atlas", agentID: "study"), "Desktop submission should be accepted")
        let atlas = store.desktopMission(for: "study")!
        check(atlas.specialistID == "study" && atlas.companyID == nil, "Desktop must use the requested specialist with personal context")
        check(store.selectedMission == original.id && store.page == "Empresas" && store.agent.id == "director", "Desktop must not navigate or retarget the main window")
        check(store.attachments.count == 1 && atlas.attachmentNames?.isEmpty == true, "Main-window attachments must stay private to that draft")
        check(!store.sendDesktop("Hello Nova", agentID: "builder"), "A busy engine must reject a second message without losing its draft")
        check(store.state.desktopChats["builder"] == nil, "A rejected message must not create a phantom conversation")
        for _ in 0..<100 where store.busy { try await Task.sleep(for: .milliseconds(10)) }
        check(!store.busy && store.desktopMission(for: "study")?.status == "Fallida", "Connection failure must release busy state and remain visible")
        store.flushStorage()
        let reloaded = AsterStore(directory: directory, startServices: false, apiFactory: failingAPI)
        check(reloaded.desktopMission(for: "study")?.id == atlas.id, "Per-agent conversation identity must survive restart")
        check(reloaded.state.desktopDrafts["study"] == "Draft for Atlas" && reloaded.state.desktopDrafts["personal"] == "Draft for Lumi", "Independent drafts must survive restart")
        check(reloaded.sendDesktop("Hello Lumi", agentID: "personal"), "A second agent should get its own conversation")
        let lumi = reloaded.desktopMission(for: "personal")!
        check(lumi.id != atlas.id && lumi.messages.first?.text == "Hello Lumi", "Agents must not share transcript or session identity")
        for _ in 0..<100 where reloaded.busy { try await Task.sleep(for: .milliseconds(10)) }
        let ai = reloaded.state.missions.firstIndex(where: { $0.id == atlas.id })!
        reloaded.state.missions[ai].status = "Por recuperar"
        let count = reloaded.state.missions[ai].messages.count
        check(!reloaded.sendDesktop("Retry without recovery", agentID: "study") && reloaded.state.missions[ai].messages.count == count, "Pending recovery must not duplicate a user message")
        reloaded.newDesktopConversation(agentID: "study")
        check(reloaded.desktopMission(for: "study") == nil && reloaded.state.missions.contains { $0.id == atlas.id }, "New chat must preserve the old conversation")
        reloaded.state.desktopChats["study"] = lumi.id
        check(reloaded.desktopMission(for: "study") == nil, "An invalid role mapping must never resume another agent's session")
        reloaded.setDesktopDraft("ignored", agentID: "missing")
        check(reloaded.state.desktopDrafts["missing"] == nil, "Unknown agents cannot create drafts")
        let legacy = try JSONDecoder().decode(SavedState.self, from: Data("{}".utf8))
        check(legacy.desktopChats.isEmpty && legacy.desktopDrafts.isEmpty, "Older app data must migrate without losing access")
        print("PASS: independent desktop chats and drafts, restart persistence, exact-agent routing, main-window and attachment isolation, busy rejection, recovery and preserved history. No network or native input was used.")
    }
}
