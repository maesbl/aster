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
    @Namespace private var navigationNamespace
    @Namespace private var agentNamespace
    @State private var draft = ""
    @State private var customizing = false
    @State private var addingCompany = false
    @State private var showNotice = false
    @State private var choosingAppearance = false
    @FocusState private var composerFocused: Bool
    var showCompanion: () -> Void
    let pages = [("Personajes", "sparkles"), ("Empresas", "building.2"), ("Misiones", "square.stack.3d.up"), ("Bandeja", "tray"), ("Conexiones", "point.3.connected.trianglepath.dotted")]
    var body: some View {
        HStack(spacing: 18) {
            sidebar
            VStack(spacing: 0) {
                toolbar
                pageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(store.page)
                    .transition(reduceMotion ? .identity : .opacity.combined(with: .offset(y: 8)))
                if store.page != "Conexiones" { composer.transition(.opacity.combined(with: .move(edge: .bottom))) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(14).padding(.top, 10)
        .frame(minWidth: 1020, minHeight: 760)
        .background(AmbientBackdrop(tint: store.agent.style.tint.color))
        .foregroundStyle(.primary)
        .tint(Color(red: 0.43, green: 0.39, blue: 0.78))
        .preferredColorScheme(AsterAppearance(rawValue: appearance)?.scheme)
        .animation(AsterMotion.spring(reduceMotion), value: store.page)
        .sheet(isPresented: $customizing) { CustomizeView(original: store.agent) { store.updateAgent($0) } }
        .sheet(isPresented: $addingCompany) { CompanyForm { store.createCompany(name: $0, goal: $1) } }
        .onChange(of: store.notice) { _, new in if !new.isEmpty { showNotice = true } }
        .alert("Aster", isPresented: $showNotice) { Button("Entendido") { store.notice = "" } } message: { Text(store.notice) }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                ZStack {
                    Circle().fill(store.agent.style.tint.color.opacity(0.5)).frame(width: 30, height: 30)
                    Image(systemName: "sparkle").font(.system(size: 16, weight: .medium)).foregroundStyle(.primary.opacity(0.7))
                }
                Text("aster").font(.system(size: 25, weight: .semibold, design: .rounded)).tracking(-0.7)
            }.padding(.top, 29).padding(.bottom, 9)
            Text("Ideas que cobran vida.").font(.system(size: 11)).foregroundStyle(muted).padding(.bottom, 29)
            ForEach(pages, id: \.0) { item in
                Button { navigate(item.0) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.1).font(.system(size: 14, weight: .medium)).frame(width: 18)
                        Text(item.0).font(.system(size: 12, weight: store.page == item.0 ? .semibold : .medium))
                        Spacer(minLength: 0)
                        if item.0 == "Bandeja" && store.unread > 0 {
                            Text("\(store.unread)").font(.system(size: 9, weight: .semibold)).frame(minWidth: 17, minHeight: 17).background(store.agent.style.tint.color.opacity(0.4), in: Capsule())
                        }
                    }.padding(.horizontal, 12).frame(height: 43)
                        .foregroundStyle(store.page == item.0 ? Color.primary : Color.secondary)
                        .background {
                            if store.page == item.0 {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(LinearGradient(colors: [store.agent.style.tint.color.opacity(scheme == .dark ? 0.3 : 0.23), .white.opacity(scheme == .dark ? 0.07 : 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(scheme == .dark ? 0.18 : 0.7)))
                                    .matchedGeometryEffect(id: "navigation", in: navigationNamespace)
                            }
                        }
                }.buttonStyle(FluidButtonStyle()).accessibilityAddTraits(store.page == item.0 ? .isSelected : []).padding(.bottom, 5)
            }
            Spacer(minLength: 22)
            HStack { Text("TU EQUIPO").font(.system(size: 9, weight: .semibold)).tracking(1.4); Spacer(); Text("\(store.state.specialists.count)").font(.system(size: 9)) }.foregroundStyle(muted).padding(.bottom, 13)
            ForEach(store.state.specialists) { agent in
                Button { select(agent.id); navigate("Personajes") } label: {
                    HStack(spacing: 9) {
                        Circle().fill(agent.style.tint.color).frame(width: 7, height: 7).overlay(Circle().stroke(.primary.opacity(0.09)))
                        Text(agent.name).font(.system(size: 12, weight: store.agent.id == agent.id ? .semibold : .regular))
                        Spacer(minLength: 2)
                        Text(agent.role).font(.system(size: 9)).foregroundStyle(muted)
                    }.foregroundStyle(store.agent.id == agent.id ? Color.primary : Color.secondary).frame(height: 31)
                }.buttonStyle(FluidButtonStyle())
            }
            Rectangle().fill(.primary.opacity(0.07)).frame(height: 1).padding(.vertical, 18)
            Button(action: showCompanion) {
                HStack(spacing: 9) {
                    Image(systemName: "macwindow.on.rectangle").font(.system(size: 13))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("En tu escritorio").font(.system(size: 11, weight: .medium))
                        Text("Siempre a mano").font(.system(size: 9)).foregroundStyle(muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.system(size: 9)).foregroundStyle(muted)
                }.padding(.vertical, 7)
            }.buttonStyle(FluidButtonStyle()).accessibilityLabel("Mostrar compañero en el escritorio").padding(.bottom, 18)
        }.padding(.horizontal, 17).frame(width: 183).frame(maxHeight: .infinity).liquidSurface(25)
    }
    private var toolbar: some View {
        HStack(spacing: 10) {
            Text(store.page).font(.system(size: 14, weight: .semibold)).padding(.leading, 6)
            Spacer()
            LiquidGroup(spacing: 12) {
                HStack(spacing: 10) {
                    HStack(spacing: 7) {
                        Circle().fill(store.busy || store.connectionStatus == "Conectado a OpenAI" ? Color.green : Color.orange).frame(width: 5, height: 5)
                        Text(store.busy ? "Trabajando" : store.connectionStatus == "Conectado a OpenAI" ? "Conectado" : "Conexión pendiente").font(.system(size: 10, weight: .medium))
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
            Text("Apariencia").font(.system(size: 13, weight: .semibold))
            ForEach(AsterAppearance.allCases, id: \.self) { value in
                Button {
                    withAnimation(AsterMotion.quick(reduceMotion)) { appearance = value.rawValue }
                    choosingAppearance = false
                } label: {
                    HStack(spacing: 10) { Image(systemName: value.symbol).frame(width: 18); Text(value.rawValue); Spacer(); if appearance == value.rawValue { Image(systemName: "checkmark").font(.system(size: 10, weight: .semibold)) } }.font(.system(size: 12)).padding(9).frame(width: 145).contentShape(Rectangle())
                }.buttonStyle(FluidButtonStyle())
            }
        }.padding(17)
    }
    @ViewBuilder private var pageContent: some View {
        switch store.page {
        case "Empresas": companies
        case "Misiones": missions
        case "Bandeja": inbox
        case "Conexiones": connections
        default: characters
        }
    }
    private func navigate(_ page: String) { withAnimation(AsterMotion.spring(reduceMotion)) { store.page = page } }
    private func select(_ id: String) { withAnimation(AsterMotion.spring(reduceMotion)) { store.select(id) } }
    private var characters: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) { Image(systemName: "sparkle"); Text("HECHO PARA TI") }.font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(muted)
                        Text("Tu equipo, contigo.").font(.system(size: 33, weight: .semibold, design: .rounded)).tracking(-1.1)
                        Text("Un poco de compañía. Un mundo de posibilidades.").font(.system(size: 12)).foregroundStyle(muted)
                    }
                    Spacer(minLength: 8)
                    GlassAction(title: "Personalizar", symbol: "paintbrush.pointed") { customizing = true }
                }.padding(.top, 6)
                characterHero
                HStack {
                    Text("Encuentra tu compañía").font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("Cinco mentes. Un mismo equipo.").font(.system(size: 10)).foregroundStyle(muted)
                }.padding(.top, 2)
                agentDock
            }.padding(.horizontal, 10).padding(.bottom, 18)
        }.scrollIndicators(.hidden)
    }
    private var characterHero: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: store.agent.id == "builder" ? "curlybraces" : store.agent.id == "growth" ? "megaphone" : store.agent.id == "strategy" ? "chart.xyaxis.line" : store.agent.id == "personal" ? "heart" : "sparkle").font(.system(size: 9))
                    Text(store.agent.role).font(.system(size: 10, weight: .medium))
                }.foregroundStyle(muted).padding(.horizontal, 10).padding(.vertical, 6).background(.primary.opacity(0.035), in: Capsule())
                Text(store.agent.name).font(.system(size: 30, weight: .semibold, design: .rounded)).tracking(-0.7).contentTransition(.interpolate)
                Text(store.agent.detail).font(.system(size: 12)).foregroundStyle(muted).lineSpacing(5).frame(maxWidth: 300, alignment: .leading).contentTransition(.opacity)
                MoodPicker(selection: $store.previewMood, tint: store.agent.style.tint.color).padding(.top, 5)
            }.padding(.leading, 25).padding(.vertical, 20)
            Spacer(minLength: 2)
            AvatarStage(style: store.agent.style, mood: store.busy ? .thinking : store.previewMood, dimension: 224)
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
                            CompanionAvatar(style: agent.style, dimension: 68)
                            HStack(spacing: 5) { Text(agent.name).font(.system(size: 11, weight: .semibold)); if store.agent.id == agent.id { Image(systemName: "checkmark.circle.fill").font(.system(size: 9)).foregroundStyle(muted) } }
                            Text(agent.role).font(.system(size: 9)).foregroundStyle(muted)
                        }.frame(maxWidth: .infinity).padding(.top, 3).padding(.bottom, 13)
                            .liquidSurface(21, tint: store.agent.id == agent.id ? agent.style.tint.color.opacity(0.16) : nil, interactive: true)
                            .liquidID(agent.id, in: agentNamespace)
                            .overlay(RoundedRectangle(cornerRadius: 21).strokeBorder(store.agent.id == agent.id ? agent.style.tint.color.opacity(0.8) : .clear, lineWidth: 1.2))
                    }.buttonStyle(FluidButtonStyle(lift: 3)).accessibilityAddTraits(store.agent.id == agent.id ? .isSelected : [])
                }
            }.padding(.vertical, 5)
        }
    }
    private var composer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 13) {
                Image(systemName: "sparkle").font(.system(size: 16)).foregroundStyle(muted).padding(.leading, 3)
                TextField(store.page == "Misiones" && store.mission != nil ? "Continúa esta misión…" : "¿Qué vamos a crear hoy?", text: $draft, axis: .vertical)
                    .lineLimit(1...4).font(.system(size: 13)).textFieldStyle(.plain).focused($composerFocused).onSubmit { submit() }
                Button { if store.busy { store.stop() } else { submit() } } label: {
                    Image(systemName: store.busy ? "stop.fill" : "arrow.up").font(.system(size: 15, weight: .semibold)).frame(width: 37, height: 37)
                        .foregroundStyle(.white).background(LinearGradient(colors: [Color(red: 0.49, green: 0.46, blue: 0.83), Color(red: 0.35, green: 0.32, blue: 0.67)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.3)))
                        .shadow(color: Color.purple.opacity(0.13), radius: 6, y: 3)
                        .contentTransition(.symbolEffect(.replace))
                }.buttonStyle(FluidButtonStyle()).disabled(!store.busy && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityLabel(store.busy ? "Detener misión" : "Enviar misión")
            }.padding(.horizontal, 15).padding(.vertical, 13).liquidSurface(25)
                .overlay(RoundedRectangle(cornerRadius: 25).strokeBorder(composerFocused ? store.agent.style.tint.color.opacity(0.7) : .clear, lineWidth: 1.2))
                .animation(AsterMotion.quick(reduceMotion), value: composerFocused)
            HStack(spacing: 6) {
                Circle().fill(store.agent.style.tint.color).frame(width: 4, height: 4)
                Text(store.busy ? store.activity : "\(store.agent.name) · \(store.agent.role)").font(.system(size: 9)).foregroundStyle(muted)
                Spacer()
                Text("Un paso a la vez. Siempre contigo.").font(.system(size: 9)).foregroundStyle(muted)
            }.padding(.horizontal, 9)
        }.padding(.horizontal, 10).padding(.top, 11).padding(.bottom, 7)
    }
    private func submit() {
        guard !store.busy, !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = draft; draft = ""; store.run(text, fresh: store.page != "Misiones" || store.mission == nil)
    }
    private var companies: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) { Text("De idea a empresa.").font(.system(size: 31, weight: .medium, design: .rounded)); Text("Un objetivo compartido para todo tu equipo.").font(.system(size: 12)).foregroundStyle(muted) }
                    Spacer(); Button("Nueva empresa") { addingCompany = true }.glassControl(prominent: true).tint(.accentColor)
                }
                if store.state.companies.isEmpty {
                    empty("building.2", title: "Aquí empieza tu próxima empresa", detail: "Añade el nombre y el objetivo. Aster podrá preparar la estrategia, el marketing y el desarrollo alrededor de ellos.")
                }
                ForEach(store.state.companies) { company in
                    VStack(alignment: .leading, spacing: 14) {
                        Text(company.name).font(.system(size: 22, weight: .medium))
                        Text(company.goal).font(.system(size: 13)).foregroundStyle(muted).textSelection(.enabled)
                        HStack(spacing: 10) {
                            companyAction("Plan de negocio", agent: "strategy", company: company, input: "Prepara un plan de negocio útil: propuesta de valor, mercado, riesgos, costes, supuestos y próximos pasos.")
                            companyAction("Marketing", agent: "growth", company: company, input: "Prepara una estrategia de marketing y un primer calendario de contenidos con objetivos medibles.")
                            companyAction("Web y producto", agent: "builder", company: company, input: "Construye una primera web para esta empresa en tu entorno, guarda los archivos en /workspace/outputs, comprueba que funciona y explica cómo revisarla. No publiques nada.")
                            companyAction("Coordinar equipo", agent: "director", company: company, input: "Coordina especialistas de negocio, marketing y desarrollo para preparar un plan de lanzamiento coherente y revisable.")
                        }.disabled(store.busy)
                    }.padding(24).frame(maxWidth: .infinity, alignment: .leading).frostedSurface(24)
                }
                Text("La creación aquí organiza un proyecto empresarial. La constitución legal, la publicación y los gastos requieren pasos posteriores.").font(.system(size: 10)).foregroundStyle(muted)
            }.padding(30)
        }
    }
    private func companyAction(_ title: String, agent: String, company: Company, input: String) -> some View {
        Button(title) { store.select(agent); store.run(input, companyID: company.id, fresh: true) }.font(.system(size: 10)).glassControl()
    }
    private var missions: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Button { store.selectedMission = nil; draft = "" } label: { Label("Nueva misión", systemImage: "plus").font(.system(size: 11)) }.glassControl()
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(store.state.missions) { mission in
                            Button { store.selectedMission = mission.id; store.artifacts = [] } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(mission.title).font(.system(size: 11, weight: .medium)).lineLimit(2).multilineTextAlignment(.leading)
                                    Text(mission.status).font(.system(size: 9)).foregroundStyle(muted)
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(store.selectedMission == mission.id ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }.padding(18).frame(width: 210).frostedSurface(22).padding(.trailing, 12)
            Rectangle().fill(ink.opacity(0.025)).frame(width: 1)
            if let mission = store.mission {
                VStack(spacing: 0) {
                    HStack {
                        Text(mission.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        Spacer()
                        GlassIconButton(symbol: "arrow.clockwise", title: "Recuperar estado y trabajo guardado", action: store.recover).disabled(store.busy || mission.sessionID == nil)
                        GlassIconButton(symbol: "square.and.arrow.up", title: "Exportar conversación", action: store.exportMission)
                        GlassIconButton(symbol: "folder", title: "Cargar archivos creados", action: store.loadArtifacts).disabled(store.busy || mission.sessionID == nil)
                    }.padding(20)
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                ForEach(mission.messages.filter { !$0.text.isEmpty }) { message in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(message.role == "user" ? "TÚ" : (store.state.specialists.first { $0.id == mission.specialistID }?.name ?? "Aster").uppercased()).font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(muted)
                                            Spacer()
                                            Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(message.text, forType: .string) } label: { Image(systemName: "doc.on.doc").font(.system(size: 10)) }.buttonStyle(.plain).accessibilityLabel("Copiar mensaje")
                                        }
                                        Text(.init(message.text)).font(.system(size: 13)).lineSpacing(5).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                    }.padding(message.role == "user" ? 16 : 0).background(message.role == "user" ? Color.accentColor.opacity(0.055) : .clear, in: RoundedRectangle(cornerRadius: 16))
                                }
                                if let error = mission.error {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Label("Esta misión necesita atención", systemImage: "exclamationmark.circle").font(.system(size: 12, weight: .medium))
                                        Text(error).font(.system(size: 12)).foregroundStyle(muted).textSelection(.enabled)
                                        HStack {
                                            Button("Recuperar estado", action: store.recover).disabled(store.busy || mission.sessionID == nil)
                                            if error.contains("facturación") { Link("Revisar cuenta OpenAI", destination: URL(string: "https://platform.openai.com/settings/organization/billing/")!) }
                                        }.font(.system(size: 11))
                                    }.padding(18).background(Color.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                                }
                                if store.busy { HStack(spacing: 9) { ProgressView().controlSize(.small); Text(store.activity).font(.system(size: 11)).foregroundStyle(muted) } }
                                ForEach(store.artifacts) { artifact in
                                    Button { store.downloadArtifact(artifact) } label: { Label(URL(fileURLWithPath: artifact.path).lastPathComponent, systemImage: "arrow.down.doc") }.glassControl().font(.system(size: 11))
                                }
                                Color.clear.frame(height: 1).id("bottom")
                            }.padding(.horizontal, 24).padding(.bottom, 24)
                        }.onChange(of: mission.messages.last?.text) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
            } else { empty("sparkle", title: "Una misión, una dirección", detail: "Pide algo concreto. El equipo guarda cada conversación y el estado real de su trabajo.") }
        }
    }
    private var inbox: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack { VStack(alignment: .leading, spacing: 8) { Text("El equipo te escribe.").font(.system(size: 30, weight: .medium, design: .rounded)); Text("Novedades, propuestas y lo que necesita tu atención.").font(.system(size: 12)).foregroundStyle(muted) }; Spacer(); Button("Revisar ahora") { Task { await store.scan() } }.glassControl() }
                if store.state.inbox.isEmpty { empty("tray", title: "Todo tranquilo por aquí", detail: "Conecta tu agenda o Apple Mail para recibir novedades. También verás los resultados de las misiones autónomas.") }
                ForEach(store.state.inbox) { note in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { if !note.read { Circle().fill(Color.purple.opacity(0.6)).frame(width: 5, height: 5) }; Text(note.title).font(.system(size: 14, weight: .medium)); Spacer(); Text(note.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 9)).foregroundStyle(muted) }
                        Text(note.text).font(.system(size: 12)).foregroundStyle(muted).lineSpacing(4).textSelection(.enabled)
                        HStack { if let id = note.missionID { Button("Abrir misión") { store.selectedMission = id; store.page = "Misiones"; store.markRead(note.id) } }; if !note.read { Button("Marcar como leído") { store.markRead(note.id) } } }.font(.system(size: 10)).glassControl()
                    }.padding(20).frostedSurface(22)
                }
            }.padding(30)
        }
    }
    private var connections: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Tu mundo, conectado.").font(.system(size: 30, weight: .medium, design: .rounded))
                Text("Elige qué puede revisar Aster y cómo quieres que trabaje.").font(.system(size: 12)).foregroundStyle(muted)
                connectionCard("OpenAI", icon: "sparkle", status: store.connectionStatus, detail: "La clave se lee desde la configuración local autorizada. No se incluye en la aplicación.") {
                    Link("Revisar facturación", destination: URL(string: "https://platform.openai.com/settings/organization/billing/")!).font(.system(size: 11))
                }
                connectionCard("Calendarios de macOS", icon: "calendar", status: store.calendarStatus, detail: "Revisa los calendarios de Apple, Google o Outlook que tengas añadidos a macOS. Aster detecta citas próximas; no modifica eventos.") {
                    if store.state.preferences.watchCalendar { Button("Desconectar") { store.state.preferences.watchCalendar = false; store.calendarStatus = "Sin conectar"; store.save() } }
                    else { Button("Conectar agenda", action: store.connectCalendar) }
                }
                connectionCard("Apple Mail", icon: "envelope", status: store.mailStatus, detail: "Revisa hasta 10 correos sin leer de las cuentas añadidas a Mail, incluidas Gmail y Outlook. Guarda remitente y asunto; no envía ni marca mensajes como leídos.") {
                    if store.state.preferences.watchMail { Button("Desconectar") { store.state.preferences.watchMail = false; store.mailStatus = "Sin conectar"; store.save() } }
                    else { Button("Conectar Apple Mail", action: store.connectMail) }
                }
                connectionCard("Notificaciones", icon: "bell", status: store.state.preferences.notifications ? "Activadas" : "Desactivadas", detail: "Recibe avisos por novedades o misiones terminadas. Las revisiones sin cambios se mantienen en silencio.") {
                    if store.state.preferences.notifications { Button("Desactivar") { store.state.preferences.notifications = false; store.save() } }
                    else { Button("Permitir avisos", action: store.requestNotifications) }
                }
                VStack(alignment: .leading, spacing: 14) {
                    HStack { Text("Trabajo autónomo").font(.system(size: 16, weight: .medium)); Spacer(); Toggle("Activar", isOn: Binding(get: { store.state.preferences.autonomous }, set: { store.state.preferences.autonomous = $0; store.save() })).toggleStyle(.switch).disabled(store.state.companies.isEmpty) }
                    Text("Aster prepara propuestas para tu primera empresa aunque no le escribas. Usa tu cuenta de OpenAI y consume saldo. Se pausa si aparece un límite de facturación.").font(.system(size: 12)).foregroundStyle(muted).lineSpacing(4)
                    HStack(spacing: 25) {
                        Picker("Cada", selection: Binding(get: { store.state.preferences.intervalHours }, set: { store.state.preferences.intervalHours = $0; store.save() })) { Text("1 hora").tag(1); Text("6 horas").tag(6); Text("24 horas").tag(24) }.frame(width: 160)
                        Stepper("Máximo \(store.state.preferences.dailyLimit) misiones/día", value: Binding(get: { store.state.preferences.dailyLimit }, set: { store.state.preferences.dailyLimit = $0; store.save() }), in: 1...6).font(.system(size: 11))
                    }
                    Text(store.state.companies.isEmpty ? "Añade una empresa para activar estas misiones." : "Empresa: \(store.state.companies[0].name)").font(.system(size: 10)).foregroundStyle(muted)
                }.padding(22).frostedSurface(22)
                VStack(alignment: .leading, spacing: 9) {
                    Label("Disponibilidad continua", systemImage: "moon.stars").font(.system(size: 14, weight: .medium))
                    Text("Las revisiones locales funcionan con Aster abierto y el Mac despierto. Los turnos ya iniciados en la nube pueden continuar al cerrar la app. Programar nuevas misiones y vigilar cuentas con el Mac apagado necesita un servicio en la nube; ese servicio todavía no está conectado.").font(.system(size: 12)).foregroundStyle(muted).lineSpacing(4)
                    Text("Los datos de Mail y Calendario permanecen en este Mac. Las instrucciones y el contexto de empresa que envías en una misión se procesan en OpenAI.").font(.system(size: 10)).foregroundStyle(muted).lineSpacing(3)
                }.padding(22).frostedSurface(22)
            }.padding(30)
        }
    }
    private func connectionCard<Content: View>(_ title: String, icon: String, status: String, detail: String, @ViewBuilder action: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: icon).font(.system(size: 15)); Text(title).font(.system(size: 15, weight: .medium)); Spacer(); action().font(.system(size: 11)).glassControl() }
            Text(status).font(.system(size: 10, weight: .medium)).foregroundStyle(muted)
            Text(detail).font(.system(size: 12)).foregroundStyle(muted).lineSpacing(4)
        }.padding(22).frostedSurface(22)
    }
    private func empty(_ icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 16) { Image(systemName: icon).font(.system(size: 27, weight: .light)).foregroundStyle(muted); Text(title).font(.system(size: 20, weight: .medium, design: .rounded)); Text(detail).font(.system(size: 12)).foregroundStyle(muted).multilineTextAlignment(.center).lineSpacing(5).frame(maxWidth: 390) }.padding(45).frame(maxWidth: .infinity, maxHeight: .infinity)
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
                VStack(alignment: .leading, spacing: 5) { Text("Hazlo tuyo.").font(.system(size: 27, weight: .semibold, design: .rounded)).tracking(-0.7); Text("Pequeños detalles. Mucha personalidad.").font(.system(size: 11)).foregroundStyle(muted) }
                Spacer(); GlassIconButton(symbol: "xmark", title: "Cerrar personalización") { dismiss() }
            }
            VStack(spacing: 0) {
                AvatarStage(style: agent.style, mood: mood, dimension: 166)
                    .id(agent.style.form.rawValue + agent.style.tint.rawValue)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.93)))
                MoodPicker(selection: $mood, tint: agent.style.tint.color).padding(.bottom, 15)
            }.frame(maxWidth: .infinity).frostedSurface(26)
            VStack(spacing: 17) {
                HStack { Text("Nombre").font(.system(size: 12, weight: .medium)); Spacer(); TextField("Nombre", text: $agent.name).textFieldStyle(.plain).padding(10).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10)).frame(width: 280) }
                Picker("Forma", selection: $agent.style.form) { ForEach(AvatarForm.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                HStack(spacing: 14) {
                    Text("Color").font(.system(size: 12, weight: .medium)); Spacer()
                    ForEach(AvatarTint.allCases, id: \.self) { tint in
                        Button { withAnimation(AsterMotion.spring(reduceMotion)) { agent.style.tint = tint } } label: {
                            Circle().fill(tint.color.gradient).frame(width: 25, height: 25).overlay(Circle().strokeBorder(.white.opacity(0.7))).padding(5)
                                .background { if agent.style.tint == tint { Circle().strokeBorder(.primary.opacity(0.55), lineWidth: 1).matchedGeometryEffect(id: "palette", in: palette) } }
                        }.buttonStyle(FluidButtonStyle(lift: 1)).accessibilityLabel(tint.rawValue).accessibilityAddTraits(agent.style.tint == tint ? .isSelected : [])
                    }
                }
                HStack { Text("Tamaño").font(.system(size: 12, weight: .medium)); Slider(value: $agent.style.size, in: 80...200).padding(.horizontal, 12); Text("\(Int(agent.style.size))").font(.system(size: 11)).foregroundStyle(muted).monospacedDigit().frame(width: 29) }
                HStack { Toggle("Movimiento", isOn: $agent.style.motion); Spacer(); Toggle("Efectos", isOn: $agent.style.effects) }.font(.system(size: 12)).toggleStyle(.switch)
            }.padding(20).frostedSurface(24)
            HStack(spacing: 6) { Image(systemName: "accessibility"); Text("Se adapta a Reducir movimiento y Reducir transparencia.") }.font(.system(size: 10)).foregroundStyle(muted)
            HStack {
                Button("Restablecer") { withAnimation(AsterMotion.spring(reduceMotion)) { if let original = Specialist.defaults.first(where: { $0.id == agent.id }) { agent = original } } }.buttonStyle(FluidButtonStyle()).font(.system(size: 11)).foregroundStyle(muted)
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
    let save: (String, String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 6) { Text("Dale una dirección.").font(.system(size: 27, weight: .semibold, design: .rounded)).tracking(-0.7); Text("Tu idea merece un buen comienzo.").font(.system(size: 12)).foregroundStyle(muted) }
                Spacer(); GlassIconButton(symbol: "xmark", title: "Cerrar formulario de empresa") { dismiss() }
            }
            VStack(alignment: .leading, spacing: 15) {
                Text("Nombre de la empresa").font(.system(size: 12, weight: .medium))
                TextField("Tu empresa", text: $name).textFieldStyle(.plain).padding(12).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 11))
                Text("¿Qué quieres conseguir?").font(.system(size: 12, weight: .medium)).padding(.top, 3)
                TextEditor(text: $goal).font(.system(size: 13)).scrollContentBackground(.hidden).frame(height: 120).padding(10).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 11))
            }.padding(20).frostedSurface(24)
            HStack { Button("Cancelar") { dismiss() }.buttonStyle(FluidButtonStyle()).font(.system(size: 12)).foregroundStyle(muted); Spacer(); GlassAction(title: "Crear espacio", symbol: "plus", prominent: true) { save(name, goal); dismiss() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(26).frame(width: 470).background(AmbientBackdrop(tint: .purple)).foregroundStyle(.primary)
    }
}

struct FloatingView: View {
    @EnvironmentObject var store: AsterStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("AsterAppearance") private var appearance = AsterAppearance.system.rawValue
    var open: () -> Void
    var hide: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            CompanionAvatar(style: store.agent.style, mood: store.busy ? .thinking : store.previewMood, dimension: CGFloat(store.agent.style.size))
                .id(store.agent.id).transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.9)))
            HStack(spacing: 6) {
                Text(store.agent.name).font(.system(size: 10, weight: .medium))
                if store.unread > 0 { Circle().fill(.purple).frame(width: 4, height: 4) }
                if store.busy { Image(systemName: "sparkle").font(.system(size: 9)) }
            }.padding(.horizontal, 13).padding(.vertical, 7).liquidSurface(18)
            PanelDragHandle().frame(width: 44, height: 13).overlay(Capsule().fill(.secondary.opacity(0.35)).frame(width: 18, height: 3).allowsHitTesting(false)).accessibilityLabel("Arrastrar compañero")
        }.padding(12).onTapGesture(count: 2, perform: open)
            .preferredColorScheme(AsterAppearance(rawValue: appearance)?.scheme)
            .animation(AsterMotion.spring(reduceMotion), value: store.agent.id)
            .contextMenu { Button("Abrir Aster", action: open); ForEach(store.state.specialists) { agent in Button(agent.name) { withAnimation(AsterMotion.spring(reduceMotion)) { store.select(agent.id) } } }; Divider(); Button("Ocultar compañero", action: hide) }
            .help("Arrastra para mover · doble clic para abrir · clic derecho para elegir personaje")
    }
}

private struct PanelDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Handle() }
    func updateNSView(_ view: NSView, context: Context) {}
    private final class Handle: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }
}
