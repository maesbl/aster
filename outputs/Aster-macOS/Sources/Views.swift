import SwiftUI
import AppKit

private let ink = Color.primary
private let paper = Color(nsColor: .windowBackgroundColor)
private let muted = Color.secondary

struct MainView: View {
    @EnvironmentObject var store: AsterStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @AppStorage("AsterAppearance") private var appearance = AsterAppearance.system.rawValue
    @AppStorage("AsterLanguage") private var language = "es"
    @Namespace private var navigationNamespace
    @Namespace private var agentNamespace
    @State private var draft = ""
    @State private var customizing = false
    @State private var addingCompany = false
    @State private var editingCompany: Company?
    @State private var renamingMission: Mission?
    @State private var missionQuery = ""
    @State private var showArchived = false
    @State private var companyFilter: UUID?
    @State private var messageViewport: CGFloat = 600
    @State private var nearBottom = true
    @State private var showNotice = false
    @State private var choosingAppearance = false
    @FocusState private var composerFocused: Bool
    var showCompanion: () -> Void
    let pages = [("Personajes", "sparkles"), ("Empresas", "building.2"), ("Actividad", "waveform.path"), ("Misiones", "square.stack.3d.up"), ("Tareas", "checklist"), ("Ordenador", "cursorarrow.motionlines"), ("Memoria", "brain"), ("Bandeja", "tray"), ("Conexiones", "point.3.connected.trianglepath.dotted")]
    var body: some View {
        HStack(spacing: 18) {
            sidebar
            VStack(spacing: 0) {
                toolbar
                pageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(store.page)
                    .transition(reduceMotion ? .identity : .opacity.combined(with: .offset(y: 8)))
                if !["Conexiones", "Memoria", "Tareas", "Ordenador", "Actividad"].contains(store.page) { composer.transition(.opacity.combined(with: .move(edge: .bottom))) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(14).padding(.top, 10)
        .frame(minWidth: 1020, minHeight: 760)
        .background(AmbientBackdrop(tint: store.agent.style.tint.color))
        .foregroundStyle(.primary)
        .tint(scheme == .dark ? .white : .black)
        .preferredColorScheme(AsterAppearance(rawValue: appearance)?.scheme)
        .environment(\.locale, Locale(identifier: language))
        .animation(AsterMotion.spring(reduceMotion), value: store.page)
        .sheet(isPresented: $customizing) { CustomizeView(original: store.agent) { store.updateAgent($0) } }
        .sheet(isPresented: $addingCompany) { CompanyForm { store.createCompany(name: $0, goal: $1, notes: $2) } }
        .sheet(item: $editingCompany) { company in CompanyForm(original: company) { name, goal, notes in var edited = company; edited.name = name; edited.goal = goal; edited.notes = notes; store.updateCompany(edited) } }
        .sheet(item: $renamingMission) { RenameMissionView(mission: $0) }
        .background(Button(L("")) { composerFocused = true }.keyboardShortcut("l", modifiers: .command).hidden())
        .onChange(of: store.notice) { _, new in if !new.isEmpty { showNotice = true } }
        .alert("Aster", isPresented: $showNotice) { Button(L("Entendido")) { store.notice = "" } } message: { Text(L(store.notice)) }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                ZStack {
                    Circle().fill(.primary.opacity(0.09)).frame(width: 30, height: 30)
                    Image(systemName: "sparkle").font(.system(size: 16, weight: .medium)).foregroundStyle(.primary.opacity(0.7))
                }
                Text(L("aster")).font(.system(size: 25, weight: .semibold, design: .rounded)).tracking(-0.7)
            }.padding(.top, 22).padding(.bottom, 9)
            Text(L("Ideas que cobran vida.")).font(.system(size: 11)).foregroundStyle(muted).padding(.bottom, 22)
            ForEach(pages, id: \.0) { item in
                Button { navigate(item.0) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.1).font(.system(size: 14, weight: .medium)).frame(width: 18)
                        Text(L(item.0)).font(.system(size: 12, weight: store.page == item.0 ? .semibold : .medium))
                        Spacer(minLength: 0)
                        if item.0 == "Bandeja" && store.unread > 0 {
                            Text("\(store.unread)").font(.system(size: 9, weight: .semibold)).frame(minWidth: 17, minHeight: 17).background(store.agent.style.tint.color.opacity(0.4), in: Capsule())
                        }
                    }.padding(.horizontal, 12).frame(height: 37)
                        .foregroundStyle(store.page == item.0 ? Color.primary : Color.secondary)
                        .background {
                            if store.page == item.0 {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.primary.opacity(scheme == .dark ? 0.12 : 0.075))
                                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(scheme == .dark ? 0.18 : 0.7)))
                                    .matchedGeometryEffect(id: "navigation", in: navigationNamespace)
                            }
                        }
                }.buttonStyle(FluidButtonStyle()).accessibilityAddTraits(store.page == item.0 ? .isSelected : []).padding(.bottom, 3)
            }
            Spacer(minLength: 10)
            HStack { Text(L("TU EQUIPO")).font(.system(size: 9, weight: .semibold)).tracking(1.4); Spacer(); Text("\(store.state.specialists.count)").font(.system(size: 9)) }.foregroundStyle(muted).padding(.bottom, 13)
            ForEach(store.state.specialists) { agent in
                Button { select(agent.id); navigate("Personajes") } label: {
                    HStack(spacing: 9) {
                        Circle().fill(agent.style.tint.color).frame(width: 7, height: 7).overlay(Circle().stroke(.primary.opacity(0.09)))
                        Text(agent.name).font(.system(size: 12, weight: store.agent.id == agent.id ? .semibold : .regular))
                        Spacer(minLength: 2)
                        Text(L(agent.role)).font(.system(size: 9)).foregroundStyle(muted)
                    }.foregroundStyle(store.agent.id == agent.id ? Color.primary : Color.secondary).frame(height: 27)
                }.buttonStyle(FluidButtonStyle())
            }
            Rectangle().fill(.primary.opacity(0.07)).frame(height: 1).padding(.vertical, 18)
            Button(action: showCompanion) {
                HStack(spacing: 9) {
                    Image(systemName: "macwindow.on.rectangle").font(.system(size: 13))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L("En tu escritorio")).font(.system(size: 11, weight: .medium))
                        Text(L("Siempre a mano")).font(.system(size: 9)).foregroundStyle(muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.system(size: 9)).foregroundStyle(muted)
                }.padding(.vertical, 7)
            }.buttonStyle(FluidButtonStyle()).accessibilityLabel(L("Mostrar compañeros en el escritorio")).padding(.bottom, 18)
        }.padding(.horizontal, 17).frame(width: 183).frame(maxHeight: .infinity).frostedSurface(25)
    }
    private var toolbar: some View {
        HStack(spacing: 10) {
            Text(L(store.page)).font(.system(size: 14, weight: .semibold)).padding(.leading, 6)
            Spacer()
            LiquidGroup(spacing: 12) {
                HStack(spacing: 10) {
                    HStack(spacing: 7) {
                        Circle().fill(store.connectionReady ? Color.green : Color.orange).frame(width: 5, height: 5)
                        Text(L(store.busy ? "Trabajando" : store.connectionStatus == "Conectado a OpenAI" ? "Conectado" : store.connectionReady ? "Clave válida" : "Conexión pendiente")).font(.system(size: 10, weight: .medium))
                    }.padding(.horizontal, 13).frame(height: 34).liquidSurface(18)
                    GlassIconButton(symbol: AsterAppearance(rawValue: appearance)?.symbol ?? "circle.lefthalf.filled", title: "Apariencia") { choosingAppearance = true }
                        .popover(isPresented: $choosingAppearance, arrowEdge: .bottom) { appearancePicker }
                    GlassIconButton(symbol: "slider.horizontal.3", title: "Ajustes y conexiones") { navigate("Conexiones") }
                }
            }
        }.padding(.horizontal, 10).padding(.top, 12).padding(.bottom, 14)
    }
    private var appearancePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Apariencia")).font(.system(size: 13, weight: .semibold))
            ForEach(AsterAppearance.allCases, id: \.self) { value in
                Button {
                    withAnimation(AsterMotion.quick(reduceMotion)) { appearance = value.rawValue }
                    choosingAppearance = false
                } label: {
                    HStack(spacing: 10) { Image(systemName: value.symbol).frame(width: 18); Text(L(value.rawValue)); Spacer(); if appearance == value.rawValue { Image(systemName: "checkmark").font(.system(size: 10, weight: .semibold)) } }.font(.system(size: 12)).padding(9).frame(width: 145).contentShape(Rectangle())
                }.buttonStyle(FluidButtonStyle())
            }
        }.padding(17)
    }
    @ViewBuilder private var pageContent: some View {
        switch store.page {
        case "Empresas": companies
        case "Misiones": missions
        case "Tareas": TaskBoardView()
        case "Actividad": ActivityWorkspaceView()
        case "Ordenador": ComputerWorkspaceView(computer: store.computer)
        case "Memoria": MemoryView()
        case "Bandeja": inbox
        case "Conexiones": SettingsView()
        default: characters
        }
    }
    private func navigate(_ page: String) { withAnimation(AsterMotion.spring(reduceMotion)) { store.page = page } }
    private func select(_ id: String) { withAnimation(AsterMotion.spring(reduceMotion)) { store.select(id) } }
    private var characters: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) { Image(systemName: "sparkle"); Text(L("HECHO PARA TI")) }.font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(muted)
                        Text(L("Tu equipo, contigo.")).font(.system(size: 33, weight: .semibold, design: .rounded)).tracking(-1.1)
                        Text(L("Un poco de compañía. Un mundo de posibilidades.")).font(.system(size: 12)).foregroundStyle(muted)
                    }
                    Spacer(minLength: 8)
                    GlassAction(title: "Personalizar", symbol: "paintbrush.pointed") { customizing = true }
                }.padding(.top, 6)
                characterHero
                HStack {
                    Text(L("Encuentra tu compañía")).font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(L("Seis mentes. Un mismo equipo.")).font(.system(size: 10)).foregroundStyle(muted)
                }.padding(.top, 2)
                agentDock
                HStack(spacing: 10) {
                    starter("Pensar una idea", symbol: "lightbulb", text: "Ayúdame a explorar una idea. Empieza con una pregunta útil y propón enfoques concretos.")
                    starter("Crear algo nuevo", symbol: "wand.and.stars", text: "Quiero crear algo original. Ayúdame a encontrar una dirección y convertirla en un primer resultado.")
                    starter("Hacer avanzar mi empresa", symbol: "arrow.up.right", text: "Ayúdame a elegir el próximo paso de mayor impacto para mi empresa y convertirlo en un plan concreto.")
                }
            }.padding(.horizontal, 10).padding(.bottom, 18)
        }.scrollIndicators(.hidden)
    }
    private var characterHero: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: store.agent.id == "builder" ? "curlybraces" : store.agent.id == "growth" ? "megaphone" : store.agent.id == "strategy" ? "chart.xyaxis.line" : store.agent.id == "personal" ? "heart" : "sparkle").font(.system(size: 9))
                    Text(L(store.agent.role)).font(.system(size: 10, weight: .medium))
                }.foregroundStyle(muted).padding(.horizontal, 10).padding(.vertical, 6).background(.primary.opacity(0.035), in: Capsule())
                Text(store.agent.name).font(.system(size: 30, weight: .semibold, design: .rounded)).tracking(-0.7).contentTransition(.interpolate)
                Text(L(store.agent.detail)).font(.system(size: 12)).foregroundStyle(muted).lineSpacing(5).frame(maxWidth: 300, alignment: .leading).contentTransition(.opacity)
                MoodPicker(selection: $store.previewMood, tint: store.agent.style.tint.color).padding(.top, 5)
            }.padding(.leading, 25).padding(.vertical, 20)
            Spacer(minLength: 2)
            AvatarStage(style: store.agent.style, mood: store.isAgentWorking(store.agent.id) ? .thinking : store.previewMood, dimension: 224)
                .id(store.agent.id).transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.90))).padding(.trailing, 14)
        }.frame(maxWidth: .infinity, minHeight: 239).frostedSurface(28)
        .animation(AsterMotion.spring(reduceMotion), value: store.agent.id)
    }
    private var agentDock: some View {
        LiquidGroup(spacing: 8) {
            HStack(spacing: 12) {
                ForEach(store.state.specialists) { agent in
                    Button { select(agent.id) } label: {
                        VStack(spacing: 3) {
                            CompanionAvatar(style: agent.style, dimension: 68, animateAtRest: false, framesPerSecond: 30)
                            HStack(spacing: 5) { Text(agent.name).font(.system(size: 11, weight: .semibold)); if store.agent.id == agent.id { Image(systemName: "checkmark.circle.fill").font(.system(size: 9)).foregroundStyle(muted) } }
                            Text(L(agent.role)).font(.system(size: 9)).foregroundStyle(muted)
                        }.frame(maxWidth: .infinity).padding(.top, 3).padding(.bottom, 13)
                            .frostedSurface(21)
                            .liquidID(agent.id, in: agentNamespace)
                            .overlay(RoundedRectangle(cornerRadius: 21).strokeBorder(store.agent.id == agent.id ? Color.primary.opacity(0.25) : .clear, lineWidth: 1.2))
                    }.buttonStyle(FluidButtonStyle(lift: 3)).accessibilityAddTraits(store.agent.id == agent.id ? .isSelected : [])
                }
            }.padding(.vertical, 5)
        }
    }
    private var composer: some View {
        VStack(spacing: 8) {
            if !store.attachments.isEmpty {
                ScrollView(.horizontal) { HStack(spacing: 8) { ForEach(store.attachments) { file in
                    HStack(spacing: 7) { Image(systemName: "doc"); Text(file.name).lineLimit(1); Button { store.removeAttachment(file.id) } label: { Image(systemName: "xmark").font(.system(size: 8, weight: .semibold)) }.buttonStyle(.plain).accessibilityLabel(L("Quitar archivo")) }.font(.system(size: 10)).padding(.horizontal, 11).padding(.vertical, 7).liquidSurface(16)
                } } }.scrollIndicators(.hidden)
            }
            HStack(spacing: 13) {
                Button(action: store.attachFiles) { Image(systemName: "plus").font(.system(size: 17, weight: .regular)).foregroundStyle(muted).frame(width: 25, height: 30) }.buttonStyle(FluidButtonStyle()).disabled(store.mainWorking).accessibilityLabel(L("Adjuntar archivos"))
                Image(systemName: "sparkle").font(.system(size: 16)).foregroundStyle(muted).padding(.leading, 3)
                TextField(L(store.page == "Misiones" && store.mission != nil ? "Continúa esta misión…" : "¿Qué vamos a crear hoy?"), text: $draft, axis: .vertical)
                    .lineLimit(1...4).font(.system(size: 13)).textFieldStyle(.plain).focused($composerFocused).onSubmit { submit() }
                Button { if store.mainWorking { store.stop() } else { submit() } } label: {
                    Image(systemName: store.mainWorking ? "stop.fill" : "arrow.up").font(.system(size: 15, weight: .semibold)).frame(width: 37, height: 37)
                        .foregroundStyle(.white).background(LinearGradient(colors: [Color(white: 0.28), Color(white: 0.13)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.3)))
                        .shadow(color: Color.black.opacity(0.1), radius: 6, y: 3)
                        .contentTransition(.symbolEffect(.replace))
                }.buttonStyle(FluidButtonStyle()).disabled(!store.mainWorking && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityLabel(L(store.mainWorking ? "Detener misión" : "Enviar misión"))
            }.padding(.horizontal, 15).padding(.vertical, 13).frostedSurface(25)
                .overlay(RoundedRectangle(cornerRadius: 25).strokeBorder(composerFocused ? store.agent.style.tint.color.opacity(0.7) : .clear, lineWidth: 1.2))
                .animation(AsterMotion.quick(reduceMotion), value: composerFocused)
            HStack(spacing: 6) {
                Circle().fill(store.agent.style.tint.color).frame(width: 4, height: 4)
                Text(store.mainWorking ? L(store.activity) : "\(store.agent.name) · \(L(store.agent.role))").font(.system(size: 9)).foregroundStyle(muted)
                Spacer()
                Menu {
                    ForEach([("low", "Rápido"), ("medium", "Equilibrado"), ("high", "Profundo")], id: \.0) { value in Button { var settings = store.settings; settings.effort = value.0; store.settings = settings } label: { if store.settings.effort == value.0 { Label(L(value.1), systemImage: "checkmark") } else { Text(L(value.1)) } } }
                } label: { Text(L(["low": "Rápido", "medium": "Equilibrado", "high": "Profundo"][store.settings.effort] ?? "Equilibrado")).font(.system(size: 9)) }.menuStyle(.borderlessButton).frame(width: 90)
            }.padding(.horizontal, 9)
        }.padding(.horizontal, 10).padding(.top, 11).padding(.bottom, 7)
    }
    private func submit() {
        guard !store.mainWorking, store.hasCapacity, !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if store.run(draft, fresh: store.page != "Misiones" || store.mission == nil) { draft = "" }
    }
    private func starter(_ title: String, symbol: String, text: String) -> some View {
        Button { draft = L(text); composerFocused = true } label: { HStack(spacing: 7) { Image(systemName: symbol).font(.system(size: 10)); Text(L(title)).font(.system(size: 10, weight: .medium)).lineLimit(1); Spacer(minLength: 1); Image(systemName: "arrow.up.left").font(.system(size: 8)) }.padding(12).frame(maxWidth: .infinity).liquidSurface(16, interactive: true) }.buttonStyle(FluidButtonStyle(lift: 1))
    }
    private var companies: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) { Text(L("De idea a empresa.")).font(.system(size: 31, weight: .medium, design: .rounded)); Text(L("Un objetivo compartido para todo tu equipo.")).font(.system(size: 12)).foregroundStyle(muted) }
                    Spacer(); Button(L("Nueva empresa")) { addingCompany = true }.glassControl(prominent: true).tint(.accentColor)
                }
                if store.companies.isEmpty {
                    empty("building.2", title: "Aquí empieza tu próxima empresa", detail: "Añade el nombre y el objetivo. Aster podrá preparar la estrategia, el marketing y el desarrollo alrededor de ellos.")
                }
                ForEach(store.companies) { company in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(company.name).font(.system(size: 22, weight: .semibold, design: .rounded)); Spacer()
                            GlassIconButton(symbol: "pencil", title: "Editar empresa") { editingCompany = company }
                            Menu { Button(L("Ver sus misiones")) { companyFilter = company.id; store.page = "Misiones" }; Button(L("Archivar empresa")) { store.archiveCompany(company.id) } } label: { Image(systemName: "ellipsis").font(.system(size: 13)).frame(width: 32, height: 32) }.menuStyle(.borderlessButton).frame(width: 32)
                        }
                        Text(company.goal).font(.system(size: 13)).foregroundStyle(muted).textSelection(.enabled)
                        if !company.notes.isEmpty { DisclosureGroup(L("Contexto de la empresa")) { Text(company.notes).font(.system(size: 12)).foregroundStyle(muted).textSelection(.enabled).padding(.top, 8) }.font(.system(size: 11)) }
                        HStack(spacing: 12) {
                            Label(LF("%d misiones", store.state.missions.filter { $0.companyID == company.id }.count), systemImage: "bubble.left.and.bubble.right")
                            Label(LF("%d tareas pendientes", store.state.tasks.filter { $0.companyID == company.id && !$0.done }.count), systemImage: "checklist")
                        }.font(.system(size: 10)).foregroundStyle(muted)
                        HStack(spacing: 10) {
                            companyAction("Plan de negocio", agent: "strategy", company: company, input: "Prepara un plan de negocio útil: propuesta de valor, mercado, riesgos, costes, supuestos y próximos pasos.")
                            companyAction("Marketing", agent: "growth", company: company, input: "Prepara una estrategia de marketing y un primer calendario de contenidos con objetivos medibles.")
                            companyAction("Web y producto", agent: "builder", company: company, input: "Construye una primera web para esta empresa en tu entorno, guarda los archivos en /workspace/outputs, comprueba que funciona y explica cómo revisarla. No publiques nada.")
                            companyAction("Coordinar equipo", agent: "director", company: company, input: "Coordina especialistas de negocio, marketing y desarrollo para preparar un plan de lanzamiento coherente y revisable.")
                        }.disabled(!store.hasCapacity)
                    }.padding(24).frame(maxWidth: .infinity, alignment: .leading).frostedSurface(24)
                }
                if store.state.companies.contains(where: { $0.archived == true }) {
                    DisclosureGroup(L("Empresas archivadas")) { ForEach(store.state.companies.filter { $0.archived == true }) { company in HStack { Text(company.name); Spacer(); Button(L("Restaurar")) { store.archiveCompany(company.id, archived: false) } }.font(.system(size: 12)).padding(.vertical, 6) } }
                }
                Text(L("La creación aquí organiza un proyecto empresarial. La constitución legal, la publicación y los gastos requieren pasos posteriores.")).font(.system(size: 10)).foregroundStyle(muted)
            }.padding(30)
        }
    }
    private func companyAction(_ title: String, agent: String, company: Company, input: String) -> some View {
        Button(L(title)) { store.select(agent); store.run(input, companyID: company.id, fresh: true) }.font(.system(size: 10)).glassControl()
    }
    private var filteredMissions: [Mission] {
        store.state.missions.filter { (showArchived ? $0.archived == true : $0.archived != true) && (companyFilter == nil || $0.companyID == companyFilter) && (missionQuery.isEmpty || $0.title.localizedCaseInsensitiveContains(missionQuery) || $0.messages.contains { $0.text.localizedCaseInsensitiveContains(missionQuery) }) }.sorted { a, b in if (a.pinned ?? false) != (b.pinned ?? false) { return a.pinned == true }; return a.updated > b.updated }
    }
    private var missions: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Button { store.selectedMission = nil; draft = "" } label: { Label(L("Nueva misión"), systemImage: "plus").font(.system(size: 11)) }.glassControl()
                TextField(L("Buscar misiones…"), text: $missionQuery).textFieldStyle(.roundedBorder).font(.system(size: 11))
                Picker(L("Empresa"), selection: $companyFilter) { Text(L("Todas")).tag(nil as UUID?); ForEach(store.companies) { Text($0.name).tag(Optional($0.id)) } }.labelsHidden().font(.system(size: 10))
                Toggle(L("Archivadas"), isOn: $showArchived).toggleStyle(.switch).font(.system(size: 10))
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(filteredMissions) { mission in
                            Button { store.openMission(mission.id); nearBottom = true } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    HStack(spacing: 4) { if mission.pinned == true { Image(systemName: "pin.fill").font(.system(size: 8)) }; Text(mission.title).font(.system(size: 11, weight: .medium)).lineLimit(2).multilineTextAlignment(.leading) }
                                    Text(L(mission.status)).font(.system(size: 9)).foregroundStyle(muted)
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(store.selectedMission == mission.id ? Color.primary.opacity(0.075) : Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain).contextMenu {
                                Button(L("Renombrar")) { renamingMission = mission }
                                Button(L(mission.pinned == true ? "Desfijar" : "Fijar")) { store.pinMission(mission.id) }
                                Button(L(mission.archived == true ? "Restaurar" : "Archivar")) { store.archiveMission(mission.id, archived: mission.archived != true) }.disabled(store.isRunning(mission.id))
                            }
                        }
                    }
                }
            }.padding(14).frame(width: 207).frostedSurface(22).padding(.trailing, 12)
            Rectangle().fill(ink.opacity(0.025)).frame(width: 1)
            if let mission = store.mission {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) { Text(mission.title).font(.system(size: 12, weight: .semibold)).lineLimit(1); HStack(spacing: 5) { Text(L(mission.status)); if let seconds = mission.elapsedSeconds { Text(L("· ") + String(format: "%.0f s", seconds)) }; if let company = store.state.companies.first(where: { $0.id == mission.companyID }) { Text(L("· ") + company.name) } }.font(.system(size: 9)).foregroundStyle(muted) }
                        Spacer()
                        GlassIconButton(symbol: "arrow.clockwise", title: "Recuperar estado y trabajo guardado", action: { store.recover() }).disabled(store.isRunning(mission.id) || !store.hasCapacity || mission.sessionID == nil)
                        GlassIconButton(symbol: "square.and.arrow.up", title: "Exportar conversación", action: store.exportMission)
                        GlassIconButton(symbol: "folder", title: "Cargar archivos creados", action: store.loadArtifacts).disabled(store.isRunning(mission.id) || !store.hasCapacity || mission.sessionID == nil)
                        Menu { Button(L("Renombrar")) { renamingMission = mission }; Button(L(mission.pinned == true ? "Desfijar" : "Fijar")) { store.pinMission(mission.id) }; Button(L(mission.archived == true ? "Restaurar" : "Archivar")) { store.archiveMission(mission.id, archived: mission.archived != true) } } label: { Image(systemName: "ellipsis").frame(width: 25, height: 25) }.menuStyle(.borderlessButton).frame(width: 25).disabled(store.isRunning(mission.id))
                    }.padding(20)
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                ForEach(mission.messages.filter { !$0.text.isEmpty }) { message in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(message.role == "user" ? L("TÚ") : (store.state.specialists.first { $0.id == mission.specialistID }?.name ?? "Aster").uppercased()).font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(muted)
                                            Text(message.date.formatted(date: .omitted, time: .shortened)).font(.system(size: 9)).foregroundStyle(muted)
                                            Spacer()
                                            if message.role == "assistant" { Button { store.speak(message.text, agentID: mission.specialistID) } label: { Image(systemName: store.speaking ? "stop.circle" : "speaker.wave.2").font(.system(size: 10)) }.buttonStyle(.plain).accessibilityLabel(L("Leer en voz alta")) }
                                            Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(message.text, forType: .string) } label: { Image(systemName: "doc.on.doc").font(.system(size: 10)) }.buttonStyle(.plain).accessibilityLabel(L("Copiar mensaje"))
                                        }
                                        RichMessage(text: message.text).equatable()
                                    }.padding(message.role == "user" ? 16 : 0).background(message.role == "user" ? Color.primary.opacity(0.045) : .clear, in: RoundedRectangle(cornerRadius: 16))
                                }
                                if let error = mission.error {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Label(L("Esta misión necesita atención"), systemImage: "exclamationmark.circle").font(.system(size: 12, weight: .medium))
                                        Text(L(error)).font(.system(size: 12)).foregroundStyle(muted).textSelection(.enabled)
                                        HStack {
                                            Button(L("Recuperar estado"), action: { store.recover() }).disabled(store.isRunning(mission.id) || !store.hasCapacity || mission.sessionID == nil)
                                            if error.contains("facturación") { Link("Revisar cuenta OpenAI", destination: URL(string: "https://platform.openai.com/settings/organization/billing/")!) }
                                        }.font(.system(size: 11))
                                    }.padding(18).background(Color.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                                }
                                if store.isRunning(mission.id) { HStack(spacing: 9) { ProgressView().controlSize(.small); Text(L(store.activity(for: mission.id))).font(.system(size: 11)).foregroundStyle(muted) } }
                                ForEach(store.artifacts) { artifact in
                                    Button { store.downloadArtifact(artifact) } label: { Label(URL(fileURLWithPath: artifact.path).lastPathComponent, systemImage: "arrow.down.doc") }.glassControl().font(.system(size: 11))
                                }
                                Color.clear.frame(height: 1).id("bottom").background(GeometryReader { geo in Color.clear.preference(key: MessageBottomKey.self, value: geo.frame(in: .named("messages")).minY) })
                            }.padding(.horizontal, 24).padding(.bottom, 24)
                        }.coordinateSpace(name: "messages")
                        .background(GeometryReader { geo in Color.clear.onAppear { messageViewport = geo.size.height }.onChange(of: geo.size.height) { _, size in messageViewport = size } })
                        .onPreferenceChange(MessageBottomKey.self) { bottom in nearBottom = bottom <= messageViewport + 150 }
                        .onChange(of: mission.messages.last?.text) { _, _ in if nearBottom { proxy.scrollTo("bottom", anchor: .bottom) } }
                        .onChange(of: mission.id) { _, _ in nearBottom = true; proxy.scrollTo("bottom", anchor: .bottom) }
                        .overlay(alignment: .bottomTrailing) { if !nearBottom { GlassIconButton(symbol: "arrow.down", title: "Ver lo último") { nearBottom = true; withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }.padding(15) } }
                    }
                }
            } else { empty("sparkle", title: "Una misión, una dirección", detail: "Pide algo concreto. El equipo guarda cada conversación y el estado real de su trabajo.") }
        }
    }
    private var inbox: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack { VStack(alignment: .leading, spacing: 8) { Text(L("El equipo te escribe.")).font(.system(size: 30, weight: .medium, design: .rounded)); Text(L("Novedades, propuestas y lo que necesita tu atención.")).font(.system(size: 12)).foregroundStyle(muted) }; Spacer(); Button(L("Revisar ahora")) { Task { await store.scan() } }.glassControl() }
                if store.state.inbox.isEmpty { empty("tray", title: "Todo tranquilo por aquí", detail: "Conecta tu agenda o Apple Mail para recibir novedades. También verás los resultados de las misiones autónomas.") }
                ForEach(store.state.inbox) { note in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { if !note.read { Circle().fill(Color.purple.opacity(0.6)).frame(width: 5, height: 5) }; Text(note.title).font(.system(size: 14, weight: .medium)); Spacer(); Text(note.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 9)).foregroundStyle(muted) }
                        Text(note.text).font(.system(size: 12)).foregroundStyle(muted).lineSpacing(4).textSelection(.enabled)
                        HStack { if let id = note.missionID { Button(L("Abrir misión")) { store.openMission(id); store.markRead(note.id) } }; if !note.read { Button(L("Marcar como leído")) { store.markRead(note.id) } } }.font(.system(size: 10)).glassControl()
                    }.padding(20).frostedSurface(22)
                }
            }.padding(30)
        }
    }
    private func empty(_ icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 16) { Image(systemName: icon).font(.system(size: 27, weight: .light)).foregroundStyle(muted); Text(L(title)).font(.system(size: 20, weight: .medium, design: .rounded)); Text(L(detail)).font(.system(size: 12)).foregroundStyle(muted).multilineTextAlignment(.center).lineSpacing(5).frame(maxWidth: 390) }.padding(45).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CustomizeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State var agent: Specialist
    @State private var mood: AvatarMood = .calm
    @Namespace private var palette
    let save: (Specialist) -> Void
    init(original: Specialist, save: @escaping (Specialist) -> Void) { _agent = State(initialValue: original); self.save = save }
    var body: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) { Text(L("Hazlo tuyo.")).font(.system(size: 27, weight: .semibold, design: .rounded)).tracking(-0.7); Text(L("Pequeños detalles. Mucha personalidad.")).font(.system(size: 11)).foregroundStyle(muted) }
                Spacer(); GlassIconButton(symbol: "xmark", title: "Cerrar personalización") { dismiss() }
            }
            VStack(spacing: 0) {
                AvatarStage(style: agent.style, mood: mood, dimension: 166)
                    .id(agent.style.form.rawValue + agent.style.tint.rawValue)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.93)))
                MoodPicker(selection: $mood, tint: agent.style.tint.color).padding(.bottom, 15)
            }.frame(maxWidth: .infinity).frostedSurface(26)
            VStack(spacing: 17) {
                HStack { Text(L("Nombre")).font(.system(size: 12, weight: .medium)); Spacer(); TextField(L("Nombre"), text: $agent.name).textFieldStyle(.plain).padding(10).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10)).frame(width: 280) }
                Picker(L("Forma"), selection: $agent.style.form) { ForEach(AvatarForm.allCases, id: \.self) { Text(L($0.rawValue)).tag($0) } }.pickerStyle(.segmented)
                HStack(spacing: 14) {
                    Text(L("Color")).font(.system(size: 12, weight: .medium)); Spacer()
                    ForEach(AvatarTint.allCases, id: \.self) { tint in
                        Button { withAnimation(AsterMotion.spring(reduceMotion)) { agent.style.tint = tint } } label: {
                            Circle().fill(tint.color.gradient).frame(width: 25, height: 25).overlay(Circle().strokeBorder(.white.opacity(0.7))).padding(5)
                                .background { if agent.style.tint == tint { Circle().strokeBorder(.primary.opacity(0.55), lineWidth: 1).matchedGeometryEffect(id: "palette", in: palette) } }
                        }.buttonStyle(FluidButtonStyle(lift: 1)).accessibilityLabel(tint.rawValue).accessibilityAddTraits(agent.style.tint == tint ? .isSelected : [])
                    }
                }
                HStack { Text(L("Tamaño")).font(.system(size: 12, weight: .medium)); Slider(value: $agent.style.size, in: 80...200).padding(.horizontal, 12); Text("\(Int(agent.style.size))").font(.system(size: 11)).foregroundStyle(muted).monospacedDigit().frame(width: 29) }
                HStack { Toggle(L("Movimiento"), isOn: $agent.style.motion); Spacer(); Toggle(L("Efectos"), isOn: $agent.style.effects) }.font(.system(size: 12)).toggleStyle(.switch)
                TextField(L("Personalidad y forma de hablar"), text: Binding(get: { agent.personality ?? "" }, set: { agent.personality = $0 }), axis: .vertical).lineLimit(1...3).textFieldStyle(.plain).padding(10).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10)).font(.system(size: 12))
            }.padding(20).frostedSurface(24)
            HStack(spacing: 6) { Image(systemName: "accessibility"); Text(L("Se adapta a Reducir movimiento y Reducir transparencia.")) }.font(.system(size: 10)).foregroundStyle(muted)
            HStack {
                Button(L("Restablecer")) { withAnimation(AsterMotion.spring(reduceMotion)) { if let original = Specialist.defaults.first(where: { $0.id == agent.id }) { agent = original } } }.buttonStyle(FluidButtonStyle()).font(.system(size: 11)).foregroundStyle(muted)
                Spacer()
                GlassAction(title: "Guardar personaje", symbol: "checkmark", prominent: true) {
                    agent.name = agent.name.trimmingCharacters(in: .whitespacesAndNewlines); if !agent.name.isEmpty { save(agent); dismiss() }
                }.disabled(agent.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(26).frame(width: 500).background(AmbientBackdrop(tint: agent.style.tint.color)).foregroundStyle(.primary)
            .animation(AsterMotion.spring(reduceMotion), value: agent.style.form)
            .animation(AsterMotion.spring(reduceMotion), value: agent.style.tint)
    }
}

struct CompanyForm: View {
    @Environment(\.dismiss) private var dismiss
    @State var name = ""
    @State var goal = ""
    @State var notes = ""
    private var editing = false
    let save: (String, String, String) -> Void
    init(original: Company? = nil, save: @escaping (String, String, String) -> Void) {
        _name = State(initialValue: original?.name ?? ""); _goal = State(initialValue: original?.goal ?? ""); _notes = State(initialValue: original?.notes ?? ""); editing = original != nil; self.save = save
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 6) { Text(L("Dale una dirección.")).font(.system(size: 27, weight: .semibold, design: .rounded)).tracking(-0.7); Text(L("Tu idea merece un buen comienzo.")).font(.system(size: 12)).foregroundStyle(muted) }
                Spacer(); GlassIconButton(symbol: "xmark", title: "Cerrar formulario de empresa") { dismiss() }
            }
            VStack(alignment: .leading, spacing: 15) {
                Text(L("Nombre de la empresa")).font(.system(size: 12, weight: .medium))
                TextField(L("Tu empresa"), text: $name).textFieldStyle(.plain).padding(12).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 11))
                Text(L("¿Qué quieres conseguir?")).font(.system(size: 12, weight: .medium)).padding(.top, 3)
                TextEditor(text: $goal).font(.system(size: 13)).scrollContentBackground(.hidden).frame(height: 90).padding(10).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 11))
                Text(L("Contexto, audiencia y recursos")).font(.system(size: 12, weight: .medium))
                TextEditor(text: $notes).font(.system(size: 12)).scrollContentBackground(.hidden).frame(height: 85).padding(10).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 11))
            }.padding(20).frostedSurface(24)
            HStack { Button(L("Cancelar")) { dismiss() }.buttonStyle(FluidButtonStyle()).font(.system(size: 12)).foregroundStyle(muted); Spacer(); GlassAction(title: editing ? "Guardar empresa" : "Crear espacio", symbol: editing ? "checkmark" : "plus", prominent: true) { save(name, goal, notes); dismiss() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(26).frame(width: 470).background(AmbientBackdrop(tint: .purple)).foregroundStyle(.primary)
    }
}

struct FloatingView: View {
    @EnvironmentObject var store: AsterStore
    @AppStorage("AsterAppearance") private var appearance = AsterAppearance.system.rawValue
    @AppStorage("AsterLanguage") private var language = "es"
    var agentID: String
    var height: CGFloat = 96
    var open: () -> Void
    var talk: () -> Void
    var arrange: () -> Void
    var hide: () -> Void
    var moved: () -> Void
    var dragStarted: () -> Void
    var hover: (Bool) -> Void
    private var agent: Specialist { store.state.specialists.first { $0.id == agentID } ?? Specialist.defaults[0] }
    private var working: Bool { store.isAgentWorking(agentID) }
    private var selected: Bool { store.agent.id == agentID }
    var body: some View {
        VStack(spacing: 2) {
            CompanionAvatar(style: agent.style, mood: working ? .thinking : selected ? store.previewMood : .calm,
                            dimension: max(1, min(64, height - 32)), animateAtRest: selected || working, framesPerSecond: 30)
            HStack(spacing: 4) {
                Text(agent.name).font(.system(size: 9, weight: selected ? .semibold : .medium)).lineLimit(1).truncationMode(.tail)
                if agentID == "director" && store.unread > 0 { Circle().fill(.primary).frame(width: 3, height: 3) }
                if working { Image(systemName: "sparkle").font(.system(size: 8)) }
            }.padding(.horizontal, 9).frame(height: 18).liquidSurface(12)
            Capsule().fill(.secondary.opacity(0.3)).frame(width: 16, height: 2)
        }.padding(4).frame(width: 94, height: height).accessibilityHidden(true)
            .overlay(CompanionInteraction(name: agent.name, open: open, talk: talk, arrange: arrange, hide: hide, moved: moved, dragStarted: dragStarted, hover: hover))
            .environment(\.locale, Locale(identifier: language))
            .preferredColorScheme(AsterAppearance(rawValue: appearance)?.scheme)
            .help(L("Cursor para hablar · arrastra para mover · doble clic para abrir Aster"))
    }
}

private struct MessageBottomKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
