from pathlib import Path
p=Path('outputs/Aster-macOS/Sources/Views.swift');s=p.read_text()
s=s.replace('@AppStorage("AsterAppearance") private var appearance = AsterAppearance.system.rawValue','@AppStorage("AsterAppearance") private var appearance = AsterAppearance.system.rawValue\n    @AppStorage("AsterLanguage") private var language = "es"',1)
s=s.replace('    @State private var showNotice', '''    @State private var editingCompany: Company?
    @State private var renamingMission: Mission?
    @State private var missionQuery = ""
    @State private var showArchived = false
    @State private var companyFilter: UUID?
    @State private var messageViewport: CGFloat = 600
    @State private var nearBottom = true
    @State private var showNotice''')
s=s.replace('("Bandeja", "tray"), ("Conexiones",', '("Tareas", "checklist"), ("Memoria", "brain"), ("Bandeja", "tray"), ("Conexiones",')
s=s.replace('.preferredColorScheme(AsterAppearance(rawValue: appearance)?.scheme)\n        .animation', '.preferredColorScheme(AsterAppearance(rawValue: appearance)?.scheme)\n        .environment(\\.locale, Locale(identifier: language))\n        .animation',1)
s=s.replace('.sheet(isPresented: $addingCompany) { CompanyForm { store.createCompany(name: $0, goal: $1) } }', '.sheet(isPresented: $addingCompany) { CompanyForm { store.createCompany(name: $0, goal: $1, notes: $2) } }\n        .sheet(item: $editingCompany) { company in CompanyForm(original: company) { name, goal, notes in var edited = company; edited.name = name; edited.goal = goal; edited.notes = notes; store.updateCompany(edited) } }\n        .sheet(item: $renamingMission) { RenameMissionView(mission: $0) }\n        .background(Button("") { composerFocused = true }.keyboardShortcut("l", modifiers: .command).hidden())')
s=s.replace('if store.page != "Conexiones" { composer', 'if !["Conexiones", "Memoria", "Tareas"].contains(store.page) { composer')
s=s.replace('Text(store.page)', 'Text(L(store.page))')
s=s.replace('store.busy || store.connectionStatus == "Conectado a OpenAI" ? Color.green : Color.orange', 'store.connectionReady ? Color.green : Color.orange')
s=s.replace('Text(store.busy ? "Trabajando" : store.connectionStatus == "Conectado a OpenAI" ? "Conectado" : "Conexión pendiente")','Text(L(store.busy ? "Trabajando" : store.connectionStatus == "Conectado a OpenAI" ? "Conectado" : store.connectionReady ? "Clave válida" : "Conexión pendiente"))')
s=s.replace('        case "Bandeja": inbox', '        case "Tareas": TaskBoardView()\n        case "Memoria": MemoryView()\n        case "Bandeja": inbox')
s=s.replace('        case "Conexiones": connections', '        case "Conexiones": SettingsView()')
s=s.replace('                agentDock\n', '''                agentDock
                HStack(spacing: 10) {
                    starter("Pensar una idea", symbol: "lightbulb", text: "Ayúdame a explorar una idea. Empieza con una pregunta útil y propón enfoques concretos.")
                    starter("Crear algo nuevo", symbol: "wand.and.stars", text: "Quiero crear algo original. Ayúdame a encontrar una dirección y convertirla en un primer resultado.")
                    starter("Hacer avanzar mi empresa", symbol: "arrow.up.right", text: "Ayúdame a elegir el próximo paso de mayor impacto para mi empresa y convertirlo en un plan concreto.")
                }
''')
# Composer attachment chips and controls.
s=s.replace('''        VStack(spacing: 8) {
            HStack(spacing: 13) {
                Image(systemName: "sparkle")''', '''        VStack(spacing: 8) {
            if !store.attachments.isEmpty {
                ScrollView(.horizontal) { HStack(spacing: 8) { ForEach(store.attachments) { file in
                    HStack(spacing: 7) { Image(systemName: "doc"); Text(file.name).lineLimit(1); Button { store.removeAttachment(file.id) } label: { Image(systemName: "xmark").font(.system(size: 8, weight: .semibold)) }.buttonStyle(.plain).accessibilityLabel("Quitar archivo") }.font(.system(size: 10)).padding(.horizontal, 11).padding(.vertical, 7).liquidSurface(16)
                } } }.scrollIndicators(.hidden)
            }
            HStack(spacing: 13) {
                Button(action: store.attachFiles) { Image(systemName: "plus").font(.system(size: 17, weight: .regular)).foregroundStyle(muted).frame(width: 25, height: 30) }.buttonStyle(FluidButtonStyle()).disabled(store.busy).accessibilityLabel("Adjuntar archivos")
                Image(systemName: "sparkle")''')
s=s.replace('Text(store.busy ? store.activity : "\\(store.agent.name) · \\(store.agent.role)")', 'Text(store.busy ? L(store.activity) : "\\(store.agent.name) · \\(L(store.agent.role))")')
s=s.replace('Text("Un paso a la vez. Siempre contigo.").font(.system(size: 9)).foregroundStyle(muted)', '''Menu {
                    ForEach([("low", "Rápido"), ("medium", "Equilibrado"), ("high", "Profundo")], id: \\.0) { value in Button { var settings = store.settings; settings.effort = value.0; store.settings = settings } label: { if store.settings.effort == value.0 { Label(L(value.1), systemImage: "checkmark") } else { Text(L(value.1)) } } }
                } label: { Text(L(["low": "Rápido", "medium": "Equilibrado", "high": "Profundo"][store.settings.effort] ?? "Equilibrado")).font(.system(size: 9)) }.menuStyle(.borderlessButton).frame(width: 90)''')
s=s.replace('        let text = draft; draft = ""; store.run(text, fresh: store.page != "Misiones" || store.mission == nil)', '        if store.run(draft, fresh: store.page != "Misiones" || store.mission == nil) { draft = "" }')
s=s.replace('    private var companies: some View {','''    private func starter(_ title: String, symbol: String, text: String) -> some View {
        Button { draft = L(text); composerFocused = true } label: { HStack(spacing: 7) { Image(systemName: symbol).font(.system(size: 10)); Text(L(title)).font(.system(size: 10, weight: .medium)).lineLimit(1); Spacer(minLength: 1); Image(systemName: "arrow.up.left").font(.system(size: 8)) }.padding(12).frame(maxWidth: .infinity).liquidSurface(16, interactive: true) }.buttonStyle(FluidButtonStyle(lift: 1))
    }
    private var companies: some View {''')
s=s.replace('store.state.companies.isEmpty', 'store.companies.isEmpty')
s=s.replace('ForEach(store.state.companies) { company in', 'ForEach(store.companies) { company in')
s=s.replace('''                        Text(company.name).font(.system(size: 22, weight: .medium))''','''                        HStack {
                            Text(company.name).font(.system(size: 22, weight: .semibold, design: .rounded)); Spacer()
                            GlassIconButton(symbol: "pencil", title: "Editar empresa") { editingCompany = company }
                            Menu { Button("Ver sus misiones") { companyFilter = company.id; store.page = "Misiones" }; Button("Archivar empresa") { store.archiveCompany(company.id) } } label: { Image(systemName: "ellipsis").font(.system(size: 13)).frame(width: 32, height: 32) }.menuStyle(.borderlessButton).frame(width: 32)
                        }''')
s=s.replace('''                        HStack(spacing: 10) {
                            companyAction''', '''                        if !company.notes.isEmpty { DisclosureGroup("Contexto de la empresa") { Text(company.notes).font(.system(size: 12)).foregroundStyle(muted).textSelection(.enabled).padding(.top, 8) }.font(.system(size: 11)) }
                        HStack(spacing: 12) {
                            Label(LF("%d misiones", store.state.missions.filter { $0.companyID == company.id }.count), systemImage: "bubble.left.and.bubble.right")
                            Label(LF("%d tareas pendientes", store.state.tasks.filter { $0.companyID == company.id && !$0.done }.count), systemImage: "checklist")
                        }.font(.system(size: 10)).foregroundStyle(muted)
                        HStack(spacing: 10) {
                            companyAction''')
s=s.replace('''                Text("La creación aquí organiza''', '''                if store.state.companies.contains(where: { $0.archived == true }) {
                    DisclosureGroup("Empresas archivadas") { ForEach(store.state.companies.filter { $0.archived == true }) { company in HStack { Text(company.name); Spacer(); Button("Restaurar") { store.archiveCompany(company.id, archived: false) } }.font(.system(size: 12)).padding(.vertical, 6) } }
                }
                Text("La creación aquí organiza''')
s=s.replace('''                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(store.state.missions)''','''                TextField("Buscar misiones…", text: $missionQuery).textFieldStyle(.roundedBorder).font(.system(size: 11))
                Picker("Empresa", selection: $companyFilter) { Text("Todas").tag(nil as UUID?); ForEach(store.companies) { Text($0.name).tag(Optional($0.id)) } }.labelsHidden().font(.system(size: 10))
                Toggle("Archivadas", isOn: $showArchived).toggleStyle(.switch).font(.system(size: 10))
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(filteredMissions)''')
s=s.replace('Button { store.selectedMission = mission.id; store.artifacts = [] }', 'Button { store.openMission(mission.id); nearBottom = true }')
s=s.replace('''                                    Text(mission.title).font''', '''                                    HStack(spacing: 4) { if mission.pinned == true { Image(systemName: "pin.fill").font(.system(size: 8)) }; Text(mission.title).font''')
s=s.replace('''.multilineTextAlignment(.leading)
                                    Text(mission.status)''','''.multilineTextAlignment(.leading) }
                                    Text(L(mission.status))''')
s=s.replace('''                            }.buttonStyle(.plain)
                        }
                    }
                }
            }.padding(18).frame(width: 210)''','''                            }.buttonStyle(.plain).contextMenu {
                                Button("Renombrar") { renamingMission = mission }
                                Button(mission.pinned == true ? "Desfijar" : "Fijar") { store.pinMission(mission.id) }
                                Button(mission.archived == true ? "Restaurar" : "Archivar") { store.archiveMission(mission.id, archived: mission.archived != true) }.disabled(store.activeMissionID == mission.id)
                            }
                        }
                    }
                }
            }.padding(14).frame(width: 207)''')
s=s.replace('''                        Text(mission.title).font(.system(size: 12, weight: .medium)).lineLimit(1)''','''                        VStack(alignment: .leading, spacing: 4) { Text(mission.title).font(.system(size: 12, weight: .semibold)).lineLimit(1); HStack(spacing: 5) { Text(L(mission.status)); if let seconds = mission.elapsedSeconds { Text("· " + String(format: "%.0f s", seconds)) }; if let company = store.state.companies.first(where: { $0.id == mission.companyID }) { Text("· " + company.name) } }.font(.system(size: 9)).foregroundStyle(muted) }''')
s=s.replace('''                        GlassIconButton(symbol: "folder", title: "Cargar archivos creados", action: store.loadArtifacts).disabled(store.busy || mission.sessionID == nil)''','''                        GlassIconButton(symbol: "folder", title: "Cargar archivos creados", action: store.loadArtifacts).disabled(store.busy || mission.sessionID == nil)
                        Menu { Button("Renombrar") { renamingMission = mission }; Button(mission.pinned == true ? "Desfijar" : "Fijar") { store.pinMission(mission.id) }; Button(mission.archived == true ? "Restaurar" : "Archivar") { store.archiveMission(mission.id, archived: mission.archived != true) } } label: { Image(systemName: "ellipsis").frame(width: 25, height: 25) }.menuStyle(.borderlessButton).frame(width: 25).disabled(store.activeMissionID == mission.id)''')
s=s.replace('''                                            Spacer()
                                            Button { NSPasteboard''','''                                            Text(message.date.formatted(date: .omitted, time: .shortened)).font(.system(size: 9)).foregroundStyle(muted)
                                            Spacer()
                                            if message.role == "assistant" { Button { store.speak(message.text) } label: { Image(systemName: store.speaking ? "stop.circle" : "speaker.wave.2").font(.system(size: 10)) }.buttonStyle(.plain).accessibilityLabel("Leer en voz alta") }
                                            Button { NSPasteboard''')
s=s.replace('''                                        Text(.init(message.text)).font(.system(size: 13)).lineSpacing(5).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)''','''                                        RichMessage(text: message.text)''')
s=s.replace('''                                if store.busy { HStack(spacing: 9)''', '''                                if store.busy && store.activeMissionID == mission.id { HStack(spacing: 9)''')
s=s.replace('''                                Color.clear.frame(height: 1).id("bottom")''','''                                Color.clear.frame(height: 1).id("bottom").background(GeometryReader { geo in Color.clear.preference(key: MessageBottomKey.self, value: geo.frame(in: .named("messages")).minY) })''')
s=s.replace('''                        }.onChange(of: mission.messages.last?.text) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }''','''                        }.coordinateSpace(name: "messages")
                        .background(GeometryReader { geo in Color.clear.onAppear { messageViewport = geo.size.height }.onChange(of: geo.size.height) { _, size in messageViewport = size } })
                        .onPreferenceChange(MessageBottomKey.self) { bottom in nearBottom = bottom <= messageViewport + 150 }
                        .onChange(of: mission.messages.last?.text) { _, _ in if nearBottom { proxy.scrollTo("bottom", anchor: .bottom) } }
                        .onChange(of: mission.id) { _, _ in nearBottom = true; proxy.scrollTo("bottom", anchor: .bottom) }
                        .overlay(alignment: .bottomTrailing) { if !nearBottom { GlassIconButton(symbol: "arrow.down", title: "Ver lo último") { nearBottom = true; withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }.padding(15) } }''')
s=s.replace('''    private var missions: some View {''','''    private var filteredMissions: [Mission] {
        store.state.missions.filter { (showArchived ? $0.archived == true : $0.archived != true) && (companyFilter == nil || $0.companyID == companyFilter) && (missionQuery.isEmpty || $0.title.localizedCaseInsensitiveContains(missionQuery) || $0.messages.contains { $0.text.localizedCaseInsensitiveContains(missionQuery) }) }.sorted { a, b in if (a.pinned ?? false) != (b.pinned ?? false) { return a.pinned == true }; return a.updated > b.updated }
    }
    private var missions: some View {''')
s=s.replace('store.selectedMission = id; store.page = "Misiones"; store.markRead(note.id)', 'store.openMission(id); store.markRead(note.id)')
# Remove obsolete settings implementation.
a=s.index('    private var connections: some View');b=s.index('    private func empty',a);s=s[:a]+s[b:]
# Company editing form.
s=s.replace('''    @State var goal = ""
    let save: (String, String) -> Void''','''    @State var goal = ""
    @State var notes = ""
    private var editing = false
    let save: (String, String, String) -> Void
    init(original: Company? = nil, save: @escaping (String, String, String) -> Void) {
        _name = State(initialValue: original?.name ?? ""); _goal = State(initialValue: original?.goal ?? ""); _notes = State(initialValue: original?.notes ?? ""); editing = original != nil; self.save = save
    }''')
s=s.replace('''                TextEditor(text: $goal).font(.system(size: 13)).scrollContentBackground(.hidden).frame(height: 120).padding(10).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 11))''','''                TextEditor(text: $goal).font(.system(size: 13)).scrollContentBackground(.hidden).frame(height: 90).padding(10).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 11))
                Text("Contexto, audiencia y recursos").font(.system(size: 12, weight: .medium))
                TextEditor(text: $notes).font(.system(size: 12)).scrollContentBackground(.hidden).frame(height: 85).padding(10).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 11))''')
s=s.replace('GlassAction(title: "Crear espacio", symbol: "plus", prominent: true) { save(name, goal);', 'GlassAction(title: editing ? "Guardar empresa" : "Crear espacio", symbol: editing ? "checkmark" : "plus", prominent: true) { save(name, goal, notes);')
# Character personality option.
s=s.replace('''                HStack { Toggle("Movimiento", isOn: $agent.style.motion); Spacer(); Toggle("Efectos", isOn: $agent.style.effects) }.font(.system(size: 12)).toggleStyle(.switch)''','''                HStack { Toggle("Movimiento", isOn: $agent.style.motion); Spacer(); Toggle("Efectos", isOn: $agent.style.effects) }.font(.system(size: 12)).toggleStyle(.switch)
                TextField("Personalidad y forma de hablar", text: Binding(get: { agent.personality ?? "" }, set: { agent.personality = $0 }), axis: .vertical).lineLimit(1...3).textFieldStyle(.plain).padding(10).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10)).font(.system(size: 12))''')
s+='''\nprivate struct MessageBottomKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}\n'''
p.write_text(s)
