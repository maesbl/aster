from pathlib import Path
p=Path('outputs/Aster-macOS/Sources/Store.swift');s=p.read_text()
s=s.replace('    @Published var busy = false\n    @Published var activity = ""','''    @Published private(set) var activities: [UUID: String] = [:]
    var busy: Bool { !activities.isEmpty }
    var activeMissionID: UUID? { if let selectedMission, isRunning(selectedMission) { return selectedMission }; return state.missions.first { isRunning($0.id) }?.id }
    var activity: String { activity(for: activeMissionID) }
    var mainWorking: Bool { isRunning(selectedMission) }
    var parallelLimit: Int { min(6, max(1, state.preferences.parallelMissions ?? 3)) }
    var hasCapacity: Bool { activities.count < parallelLimit }
    func isRunning(_ id: UUID?) -> Bool { id.map { activities[$0] != nil } ?? false }
    func isAgentWorking(_ id: String) -> Bool { state.missions.contains { $0.specialistID == id && isRunning($0.id) } }
    func activity(for id: UUID?) -> String { id.flatMap { activities[$0] } ?? "" }
    func setActivity(_ text: String, for id: UUID) { if runtimes[id] != nil { activities[id] = text } }
    private final class Runtime {
        var task: Task<Void, Never>?
        var deadlineTask: Task<Void, Never>?
        var streamFlushTask: Task<Void, Never>?
        var parts: [String: String] = [:]
        var partOrder: [String] = []
        var lastStreamSave = Date.distantPast
        var cancelRequested = false
    }
    private var runtimes: [UUID: Runtime] = [:]''')
s=s.replace('    @Published var activeMissionID: UUID?\n','')
a=s.index('    private var task: Task<Void, Never>?');b=s.index('    private var scanning',a)
s=s[:a]+'    private var timer: Timer?\n'+s[b:]
s=s.replace('guard activeMissionID != id else','guard !isRunning(id) else').replace('guard !busy else { return }\n        let panel = NSOpenPanel()', 'guard !mainWorking else { return }\n        let panel = NSOpenPanel()')
s=s.replace('guard desktopMission(for: agentID)?.id != activeMissionID || !busy else', 'guard !isRunning(desktopMission(for: agentID)?.id) else')
s=s.replace('missionID: UUID? = nil, specialistID: String? = nil, desktop: Bool = false)', 'missionID: UUID? = nil, specialistID: String? = nil, desktop: Bool = false, background: Bool = false)')
s=s.replace('guard !text.isEmpty, !busy else { return false }', 'guard !text.isEmpty, hasCapacity else { return false }')
s=s.replace('let intendedMission = desktop ? missionID : selectedMission', 'let intendedMission = desktop || background ? missionID : selectedMission')
s=s.replace('            index = current\n', '            index = current\n            guard !isRunning(intendedMission) else { return false }\n')
s=s.replace('if !desktop { selectedMission', 'if !desktop && !background { selectedMission').replace('let attached = desktop ? [] : attachments', 'let attached = desktop || background ? [] : attachments').replace('if !desktop { attachments', 'if !desktop && !background { attachments')
s=s.replace('        task = Task { [weak self] in', '        runtimes[id]?.task = Task { [weak self] in',1)
a=s.index('    private func startWork');b=s.index('    private func setStatus',a)
s=s[:a]+'''    func startWork(_ id: UUID) {
        guard runtimes[id] == nil else { return }
        let runtime = Runtime(); runtimes[id] = runtime; activities[id] = "Preparando la sesión"
        let minutes = min(60, max(1, settings.maxMinutes))
        runtime.deadlineTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(minutes * 60)); guard let self, self.isRunning(id) else { return }; self.notice = "Se ha alcanzado el tiempo máximo de esta misión. Aster solicita su cancelación."; self.stop(missionID: id) } catch {}
        }
    }
    func finishWork(_ id: UUID) {
        flush(id); guard let runtime = runtimes.removeValue(forKey: id) else { return }
        runtime.deadlineTask?.cancel(); runtime.streamFlushTask?.cancel()
        if let i = state.missions.firstIndex(where: { $0.id == id }), let started = state.missions[i].started { state.missions[i].elapsedSeconds = Date().timeIntervalSince(started) }
        activities.removeValue(forKey: id); save()
    }
    func handle(_ event: AgentEvent, id: UUID) {
        guard let runtime = runtimes[id], let index = state.missions.firstIndex(where: { $0.id == id }) else { return }
        switch event {
        case .session(let session): state.missions[index].sessionID = session; save()
        case .turn(let turn): state.missions[index].turnID = turn; setActivity("El agente está trabajando", for: id); save()
        case .text(let item, let text, let complete):
            if runtime.parts[item] == nil { runtime.partOrder.append(item) }
            runtime.parts[item] = complete ? text : (runtime.parts[item] ?? "") + text
            if runtime.streamFlushTask == nil { runtime.streamFlushTask = Task { [weak self, weak runtime] in
                do { try await Task.sleep(for: .milliseconds(70)); self?.flush(id); runtime?.streamFlushTask = nil } catch {}
            } }
        case .activity(let message): setActivity(message, for: id)
        case .actions: setActivity("Consultando el espacio de trabajo", for: id)
        default: flush(id)
        }
    }
    private func flush(_ id: UUID) {
        guard let runtime = runtimes[id], !runtime.partOrder.isEmpty, let i = state.missions.firstIndex(where: { $0.id == id }), let last = state.missions[i].messages.lastIndex(where: { $0.role == "assistant" }) else { return }
        state.missions[i].messages[last].text = runtime.partOrder.compactMap { runtime.parts[$0] }.joined(separator: "\\n\\n")
        if Date().timeIntervalSince(runtime.lastStreamSave) > 2 { runtime.lastStreamSave = Date(); save() }
    }
''' + s[b:]
s=s.replace('parts = [:]; partOrder = []', 'runtimes[id]?.parts = [:]; runtimes[id]?.partOrder = []')
s=s.replace('} catch { notice = "La respuesta terminó, pero no se ha podido reconciliar el texto guardado: " + error.localizedDescription }','} catch { setStatus(id, "Por recuperar", error: "No se ha podido verificar el resultado: " + error.localizedDescription); return }')
s=s.replace('func stop() {\n        guard let item = state.missions.first(where: { $0.id == activeMissionID }), busy, !cancelRequested else', 'func stop(missionID: UUID? = nil) {\n        guard let item = state.missions.first(where: { $0.id == (missionID ?? selectedMission) }), let runtime = runtimes[item.id], !runtime.cancelRequested else')
s=s.replace('        cancelRequested = true','        runtime.cancelRequested = true').replace('try await AgentAPI().cancel(sid)', 'try await makeAPI().cancel(sid)').replace('activity = "Confirmando la cancelación"', 'setActivity("Confirmando la cancelación", for: item.id)').replace('if activeMissionID == item.id && cancelRequested { task?.cancel() }', 'if runtimes[item.id] === runtime && runtime.cancelRequested { runtime.task?.cancel() }').replace('} catch { cancelRequested = false;', '} catch { runtime.cancelRequested = false;')
s=s.replace('let sid = item.sessionID, !busy else', 'let sid = item.sessionID, hasCapacity, !isRunning(item.id) else')
s=s.replace('startWork(item.id); activity = "Recuperando el trabajo guardado"\n        task = Task', 'startWork(item.id); setActivity("Recuperando el trabajo guardado", for: item.id)\n        runtimes[item.id]?.task = Task').replace('activity = "Retomando la misión"', 'setActivity("Retomando la misión", for: item.id)')
s=s.replace('state.preferences.dailyRuns += 1; state.preferences.selectedAgent = "director";', 'state.preferences.dailyRuns += 1;')
s=s.replace('companyID: company.id, fresh: true, proactive: true)', 'companyID: company.id, fresh: true, proactive: true, specialistID: "director", background: true)')
p.write_text(s)
p=Path('outputs/Aster-macOS/Sources/Models.swift');s=p.read_text().replace('    var autonomousBrief: String?', '    var autonomousBrief: String?\n    var parallelMissions: Int?');p.write_text(s)
p=Path('outputs/Aster-macOS/Sources/MacServices.swift');s=p.read_text().replace('activity = "Leyendo Apple Mail"', 'setActivity("Leyendo Apple Mail", for: missionID)');p.write_text(s)
# UI actions must target their conversation, independent of other active agents.
p=Path('outputs/Aster-macOS/Sources/Views.swift');s=p.read_text();s=s.replace('store.busy ? .thinking', 'store.isAgentWorking(store.agent.id) ? .thinking')
a=s.index('    private var composer:');b=s.index('    private var companies',a) if '    private var companies' in s[a:] else s.index('    private var company',a)
chunk=s[a:b].replace('store.busy', 'store.mainWorking').replace('guard !store.mainWorking,','guard !store.mainWorking, store.hasCapacity,')
s=s[:a]+chunk+s[b:]
s=s.replace('.disabled(store.busy)', '.disabled(!store.hasCapacity)').replace('store.activeMissionID == mission.id','store.isRunning(mission.id)').replace('store.busy || mission.sessionID == nil','store.isRunning(mission.id) || !store.hasCapacity || mission.sessionID == nil').replace('store.busy && store.isRunning(mission.id)', 'store.isRunning(mission.id)').replace('Text(L(store.activity)).font(.system(size: 11))','Text(L(store.activity(for: mission.id))).font(.system(size: 11))').replace('store.busy && store.state.missions.first(where: { $0.id == store.activeMissionID })?.specialistID == agentID','store.isAgentWorking(agentID)')
p.write_text(s)
p=Path('outputs/Aster-macOS/Sources/DesktopChatView.swift');s=p.read_text().replace('store.busy && store.activeMissionID == mission?.id','store.isRunning(mission?.id)').replace('.disabled(store.busy)', '.disabled(!store.hasCapacity)').replace('if store.busy, !working', 'if !store.hasCapacity, !working').replace('store.activity', 'store.activity(for: mission?.id)').replace('store.stop()', 'store.stop(missionID: mission?.id)').replace('.disabled(store.busy ||', '.disabled(!store.hasCapacity ||');p.write_text(s)
p=Path('outputs/Aster-macOS/Sources/DesktopCompanions.swift');s=p.read_text().replace('self.store.desktopMission(for: id)?.id != self.store.activeMissionID || !self.store.busy', '!self.store.isRunning(self.store.desktopMission(for: id)?.id)');p.write_text(s)
p=Path('outputs/Aster-macOS/Sources/WorkspaceViews.swift');s=p.read_text().replace('.disabled(store.busy)', '.disabled(!store.hasCapacity)');p.write_text(s)
p=Path('outputs/Aster-macOS/Sources/ComputerView.swift');s=p.read_text().replace(' || store.busy)', ')');p.write_text(s)
