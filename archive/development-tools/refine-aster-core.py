from pathlib import Path
p=Path('outputs/Aster-macOS/Sources/Store.swift');s=p.read_text()
s=s.replace('''    func save() {
        do { let data = try JSONEncoder().encode(state); try data.write(to: file, options: [.atomic]); onFloatingChange?() }
        catch { notice = "No se han podido guardar los cambios: \\(error.localizedDescription)" }
    }''','''    private func persist() throws { try JSONEncoder().encode(state).write(to: file, options: [.atomic]) }
    func save() {
        do { try persist(); onFloatingChange?() }
        catch { notice = "No se han podido guardar los cambios: \\(error.localizedDescription)" }
    }''')
s=s.replace('''    func updateMemory(_ entry: MemoryEntry) { if let i = state.memories.firstIndex(where: { $0.id == entry.id }) { state.memories[i] = entry; save() } }''','''    func updateMemory(_ entry: MemoryEntry) {
        guard !entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !entry.text.contains("sk-"), entry.text.count <= 8000 else { notice = "La memoria debe ser un texto de hasta 8.000 caracteres, sin claves de acceso."; return }
        if let i = state.memories.firstIndex(where: { $0.id == entry.id }) { state.memories[i] = entry; save() }
    }''')
s=s.replace('state.memories.filter { $0.companyID == nil || $0.companyID == company?.id }.prefix(50).map(\\.text)', 'memoryContext(companyID: company?.id)')
s=s.replace('''    private func inputContext''','''    private func memoryContext(companyID: UUID?) -> [String] {
        var used = 0; var result: [String] = []
        for entry in state.memories.filter({ $0.companyID == nil || $0.companyID == companyID }).prefix(50) {
            let text = String(entry.text.prefix(max(0, 24000 - used))); guard !text.isEmpty else { break }; result.append(text); used += text.count
        }
        return result
    }
    private func inputContext''')
s=s.replace('''        let company = state.companies.first { $0.id == mission.companyID }; var output''','''        let previous = state
        let company = state.companies.first { $0.id == mission.companyID }; var output''')
s=s.replace('''        state.toolReceipts.append(.init(sessionID: sessionID, turnID: call.turnID, callID: call.callID, output: result)); save()
        return result''','''        state.toolReceipts.append(.init(sessionID: sessionID, turnID: call.turnID, callID: call.callID, output: result))
        do { try persist() } catch { state = previous; throw AsterError.message("No se ha podido guardar el resultado de la herramienta. La operación no se ha confirmado.") }
        return result''')
s=s.replace('''        task = Task {
            do {
                let api = try AgentAPI(); let result''','''        task = Task { [self] in
            do {
                let api = try AgentAPI(); let result''')
s=s.replace('''let day = now.formatted(.iso8601.year().month().day())''','''let day = AutonomyPolicy.dayStamp(now)''')
s=s.replace('''enum AutonomyPolicy {
    static func canRun''','''enum AutonomyPolicy {
    static func dayStamp(_ now: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
    static func canRun''')
p.write_text(s)
p=Path('outputs/Aster-macOS/Sources/Design.swift');s=p.read_text()
# Read the locale in reusable controls so changing interface language refreshes their labels.
for declaration in ['struct GlassAction: View {','struct GlassIconButton: View {','struct MoodPicker: View {']:
 s=s.replace(declaration,declaration+'\n    @Environment(\\.locale) private var locale')
s=s.replace('Label(L(title), systemImage:', 'Label(L(title, language: locale.language.languageCode?.identifier), systemImage:')
s=s.replace('.accessibilityLabel(L(title)).help(L(title))','.accessibilityLabel(L(title, language: locale.language.languageCode?.identifier)).help(L(title, language: locale.language.languageCode?.identifier))')
s=s.replace('Text(L(mood.rawValue))','Text(L(mood.rawValue, language: locale.language.languageCode?.identifier))')
p.write_text(s)
p=Path('outputs/Aster-macOS/Sources/Views.swift');s=p.read_text().replace('Button(title) { store.select(agent)', 'Button(L(title)) { store.select(agent)')
s=s.replace('Text(store.notice)', 'Text(L(store.notice))').replace('Text(error)', 'Text(L(error))').replace('if case ', 'if case ')
s=s.replace('''    @AppStorage("AsterAppearance") private var appearance = AsterAppearance.system.rawValue
    var open:''','''    @AppStorage("AsterAppearance") private var appearance = AsterAppearance.system.rawValue
    @AppStorage("AsterLanguage") private var language = "es"
    var open:''')
s=s.replace('''        }.padding(12).onTapGesture(count: 2, perform: open)''','''        }.padding(12).onTapGesture(count: 2, perform: open).environment(\\.locale, Locale(identifier: language))''')
p.write_text(s)
p=Path('outputs/Aster-macOS/Sources/AgentAPI.swift');s=p.read_text().replace('''        guard let result = try JSONSerialization.jsonObject(with: data)''','''        if data.isEmpty { return [:] }
        guard let result = try JSONSerialization.jsonObject(with: data)''')
s=s.replace('''    func observe(_ sessionID: String, toolHandler:''','''    func observe(_ sessionID: String, turnID: String? = nil, toolHandler:''').replace('let result = try await recover(sessionID, turnID: nil)', 'let result = try await recover(sessionID, turnID: turnID)')
p.write_text(s)
p=Path('outputs/Aster-macOS/Sources/Store.swift');s=p.read_text().replace('try await api.observe(sid, toolHandler:', 'try await api.observe(sid, turnID: item.turnID, toolHandler:');p.write_text(s)
p=Path('outputs/Aster-macOS/Sources/App.swift');s=p.read_text()
s=s.replace('''        window.contentView = NSHostingView(rootView: view); window.center()''','''        window.contentView = NSHostingView(rootView: view); window.setFrameAutosaveName("AsterMain"); if !window.setFrameUsingName("AsterMain") { window.center() }''')
s=s.replace('''        openMain(); showCompanion()
    }''','''        localizeMenus()
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.localizeMenus() } }
        openMain(); showCompanion()
    }
    private func localizeMenus() {
        func translate(_ menu: NSMenu) {
            if menu.representedObject == nil { } // Item titles carry stable translation keys below.
            for item in menu.items {
                if item.representedObject == nil { item.representedObject = item.title }
                if let key = item.representedObject as? String { item.title = L(key) }
                if let submenu = item.submenu { translate(submenu); if let key = item.representedObject as? String, !key.isEmpty { submenu.title = L(key) } }
            }
        }
        if let menu = NSApplication.shared.mainMenu { translate(menu) }
        if let menu = statusItem.menu { translate(menu) }
    }''')
s=s.replace('''            if menu.representedObject == nil { } // Item titles carry stable translation keys below.
''','')
# Root menu items are initialized from their submenu titles so translation keys stay stable.
s=s.replace('let editRoot = NSMenuItem();', 'let editRoot = NSMenuItem(title: "Edición", action: nil, keyEquivalent: "");').replace('let windowsRoot = NSMenuItem();', 'let windowsRoot = NSMenuItem(title: "Ventana", action: nil, keyEquivalent: "");')
p.write_text(s)
