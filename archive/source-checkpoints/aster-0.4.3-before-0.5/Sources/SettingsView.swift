import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AsterStore
    @AppStorage("AsterLanguage") private var language = "es"
    @State private var tab = "Inteligencia"
    private let tabs = ["Inteligencia", "Voces", "Conexiones", "Autonomía"]
    private func option<Value>(_ path: WritableKeyPath<IntelligenceSettings, Value>) -> Binding<Value> {
        Binding(get: { store.settings[keyPath: path] }, set: { value in var settings = store.settings; settings[keyPath: path] = value; store.settings = settings })
    }
    private func preference<Value>(_ path: WritableKeyPath<Preferences, Value>) -> Binding<Value> {
        Binding(get: { store.state.preferences[keyPath: path] }, set: { store.state.preferences[keyPath: path] = $0; store.save() })
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Aster, a tu manera.")).font(.system(size: 30, weight: .semibold, design: .rounded)).tracking(-0.8)
                        Text(L("Elige cómo piensa, cómo habla y cuándo trabaja.")).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer(); GlassAction(title: "Guardar copia", symbol: "square.and.arrow.up", action: store.exportWorkspace)
                }
                Picker(L("Ajustes"), selection: $tab) { ForEach(tabs, id: \.self) { Text(L($0)).tag($0) } }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: 460)
                if tab == "Inteligencia" { intelligence }
                else if tab == "Voces" { voices }
                else if tab == "Conexiones" { connections }
                else { autonomy }
            }.padding(.horizontal, 22).padding(.top, 9).padding(.bottom, 28)
        }.scrollIndicators(.hidden)
    }
    private var intelligence: some View {
        VStack(spacing: 18) {
            card("Su forma de pensar", icon: "sparkle") {
                let models = ["gpt-6-astra", "gpt-6.1-sol", "gpt-6-sol", "gpt-6-luna", "gpt-5.4-mini"].filter { store.availableModels.isEmpty || store.availableModels.contains($0) || $0 == store.settings.model }
                Picker(L("Modelo"), selection: option(\.model)) { ForEach(models, id: \.self) { Text($0).tag($0) } }
                Picker(L("Profundidad"), selection: option(\.effort)) { Text(L("Rápido")).tag("low"); Text(L("Equilibrado")).tag("medium"); Text(L("Profundo")).tag("high") }
                Text(L("Más profundidad puede mejorar tareas complejas y aumentar el tiempo y el consumo. Los cambios se aplican en el próximo envío.")).font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
                Toggle(L("Investigar en internet"), isOn: option(\.webSearch)).toggleStyle(.switch)
                Toggle(L("Permitir que Aster coordine especialistas"), isOn: option(\.delegation)).toggleStyle(.switch)
                if store.settings.delegation { Stepper(LF("Hasta %d especialistas a la vez", store.settings.maxAgents), value: option(\.maxAgents), in: 1...5) }
                Stepper(LF("Tiempo máximo por misión: %d min", store.settings.maxMinutes), value: option(\.maxMinutes), in: 1...60)
                Text(L("Aster solicita la cancelación al alcanzar este tiempo mientras la app está abierta. No es un límite monetario de OpenAI.")).font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(4)
            }
            card("Idioma y personalidad", icon: "bubble.left.and.bubble.right") {
                Picker(L("Idioma de la interfaz"), selection: $language) { ForEach(AsterLanguage.allCases, id: \.rawValue) { Text($0.name).tag($0.rawValue) } }
                Picker(L("Idioma de las respuestas"), selection: option(\.responseLanguage)) {
                    Text(L("El de mi mensaje")).tag("auto")
                    ForEach([("es", "Español"), ("en", "English"), ("ca", "Català"), ("fr", "Français"), ("de", "Deutsch"), ("it", "Italiano"), ("pt", "Português"), ("ja", "日本語"), ("zh", "中文")], id: \.0) { Text($0.1).tag($0.0) }
                }
                Picker(L("Tono"), selection: option(\.tone)) { Text(L("Cercano")).tag("warm"); Text(L("Directo")).tag("direct"); Text(L("Profesional")).tag("professional"); Text(L("Creativo")).tag("creative") }
                Picker(L("Detalle"), selection: option(\.detail)) { Text(L("Breve")).tag("brief"); Text(L("Equilibrado")).tag("balanced"); Text(L("Exhaustivo")).tag("detailed") }
                TextField(L("Cómo quieres que te llame"), text: option(\.userName)).textFieldStyle(.roundedBorder)
                Text(L("Tus preferencias e instrucciones")).font(.system(size: 11, weight: .medium))
                TextEditor(text: option(\.instructions)).font(.system(size: 12)).scrollContentBackground(.hidden).frame(height: 85).padding(10).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
            }
            card("Memoria y contexto", icon: "brain") {
                Toggle(L("Usar la memoria guardada"), isOn: option(\.useMemory)).toggleStyle(.switch)
                Toggle(L("Recordar cuando se lo pida"), isOn: option(\.automaticMemory)).toggleStyle(.switch)
                Text(L("Puedes ver, editar y eliminar los recuerdos en Memoria. Aster no guarda automáticamente cada conversación como un recuerdo.")).font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
                Toggle(L("Compartir resúmenes de agenda y correo con la IA"), isOn: option(\.shareSources)).toggleStyle(.switch)
                Text(L("Al activarlo, los asuntos y remitentes de correo y los títulos y horarios de citas ya revisados se envían a OpenAI con tus misiones. Las fuentes se conectan por separado.")).font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(4)
            }
        }
    }
    private var connections: some View {
        VStack(spacing: 18) {
            card("OpenAI", icon: "sparkle") {
                HStack { Text(L(store.connectionStatus)).font(.system(size: 11, weight: .medium)); Spacer(); Button(L("Comprobar conexión"), action: store.refreshConnection).disabled(store.checkingConnection) }
                if store.checkingConnection { ProgressView().controlSize(.small) }
                HStack { Button(L("Probar una respuesta")) { store.select("personal"); store.run("Salúdame brevemente en mi idioma y dime una forma concreta en la que puedes ayudarme a pensar y crear hoy.", fresh: true) }.disabled(store.busy); Link(L("Cuenta OpenAI"), destination: URL(string: "https://platform.openai.com/settings/organization/billing/")!) }
                Text(L("La clave se lee desde tu configuración local. Comprobar conexión verifica la clave y el modelo; Probar una respuesta ejecuta una misión real y consume saldo.")).font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
            }
            card("Calendarios de macOS", icon: "calendar") {
                HStack { Text(L(store.calendarStatus)).font(.system(size: 11)); Spacer(); Button(L(store.state.preferences.watchCalendar ? "Revisar permiso" : "Conectar agenda"), action: store.connectCalendar); if store.state.preferences.watchCalendar { Button(L("Desconectar")) { store.state.preferences.watchCalendar = false; store.calendarStatus = "Sin conectar"; store.save() } } }
                Text(L("Lee las próximas citas de las cuentas añadidas a Calendario, incluidas Apple, Google y Outlook. Las novedades aparecen en tu bandeja.")).font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
            }
            card("Apple Mail", icon: "envelope") {
                HStack { Text(L(store.mailStatus)).font(.system(size: 11)).lineLimit(3); Spacer(); Button(L(store.state.preferences.watchMail ? "Comprobar Mail" : "Conectar Apple Mail"), action: store.connectMail); if store.state.preferences.watchMail { Button(L("Desconectar")) { store.state.preferences.watchMail = false; store.mailStatus = "Sin conectar"; store.save() } } }
                Text(L("Pídele el último correo, una búsqueda o un resumen: Aster abre el mensaje real y lee su contenido. Funciona con las cuentas añadidas a Mail, incluidas Gmail y Outlook.")).font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
            }
            card("Recordatorios de Apple", icon: "checklist") {
                HStack { Text(L(store.remindersStatus)).font(.system(size: 11)).lineLimit(3); Spacer(); Button(L(store.state.preferences.watchReminders == true ? "Revisar permiso" : "Conectar Recordatorios"), action: store.connectReminders); if store.state.preferences.watchReminders == true { Button(L("Desconectar")) { store.state.preferences.watchReminders = false; store.reminders = []; store.remindersStatus = "Sin conectar"; store.save() } } }
                Text(L("Consulta tus listas, crea recordatorios con fecha y marca tareas completadas desde la conversación. También los verás en Tareas → Apple.")).font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
            }
            card("Tu ordenador", icon: "cursorarrow.motionlines") {
                Text(L("Abre Ordenador para conectar la pantalla y el cursor, elegir un compañero y darle una tarea. Puedes ver cada paso, pausarlo o detenerlo con Esc.")).font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
                Button(L("Abrir Ordenador")) { store.page = "Ordenador" }
            }
            card("Apple Salud", icon: "heart") {
                if let health = store.state.health {
                    HStack { Text(L("Última importación:") + " " + health.imported.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11)); Spacer(); Button(L("Eliminar datos de Salud")) { store.state.health = nil; store.save() } }
                    Text(LF("%d registros · %d tipos de datos", health.recordCount, health.metrics.count)).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Text(L("Salud no permite leer sus datos directamente desde macOS. Puedes importar export.xml desde Salud → tu perfil → Exportar todos los datos de salud en el iPhone y preguntarle a Aster por esos registros. La importación muestra su fecha y no se actualiza sola.")).font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
                Button(L("Importar Apple Salud"), action: store.importHealth)
            }
            card("Google", icon: "globe") {
                Text(L("Gmail y Google Calendar funcionan aquí si sus cuentas ya están añadidas a Mail y Calendario de macOS. La conexión directa de Gmail, Drive y Calendar queda pendiente de la configuración de Google que has dejado para más adelante.")).font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
            }
            card("Notificaciones", icon: "bell") {
                HStack { Text(L(store.state.preferences.notifications ? "Activadas" : "Desactivadas")); Spacer(); if store.state.preferences.notifications { Button(L("Desactivar"), action: store.disableNotifications) } else { Button(L("Permitir avisos"), action: store.requestNotifications) } }
                Text(L("Pide «recuérdame mañana a las 9…» o crea un aviso en Tareas. macOS entrega los avisos programados aunque cierres la ventana de Aster. También recibirás novedades y resultados del equipo.")).font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
                Button(L("Abrir ajustes de notificaciones")) { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!) }.font(.system(size: 11))
            }
        }
    }
    private var voices: some View {
        VStack(spacing: 18) {
            card("Una voz para cada compañero", icon: "waveform") {
                Picker(L("Tipo de voz"), selection: Binding(get: { store.state.preferences.voiceEngine ?? "natural" }, set: { store.voice.stop(); store.state.preferences.voiceEngine = $0; store.save() })) { Text(L("Natural · OpenAI")).tag("natural"); Text(L("Voces de macOS")).tag("system") }
                Text(L("Las voces naturales son generadas por IA. Leen en el idioma del texto y usan tu saldo de OpenAI. Las voces de macOS funcionan sin esa conexión.")).font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
                ForEach(store.state.specialists) { agent in
                    HStack { Circle().fill(agent.style.tint.color).frame(width: 7, height: 7); Text(agent.name).font(.system(size: 12, weight: .medium)).frame(width: 65, alignment: .leading); Picker(L("Voz"), selection: Binding(get: { store.state.preferences.agentVoices?[agent.id] ?? AsterVoice.defaultID(agent.id) }, set: { store.state.preferences.agentVoices = (store.state.preferences.agentVoices ?? [:]).merging([agent.id: $0]) { _, new in new }; store.save() })) { ForEach(AsterVoice.all) { Text(L($0.label)).tag($0.id) } }.labelsHidden().disabled(store.state.preferences.voiceEngine == "system"); Button(L("Escuchar")) { store.select(agent.id); store.speak(L("Hola. Estoy aquí para pensar contigo, ayudarte a crear y acompañarte en lo que necesites.")) } }.font(.system(size: 11))
                }
                if store.speaking { Button(L("Detener voz")) { store.voice.stop() } }
            }
            card("Mientras trabaja en tu Mac", icon: "speaker.wave.2") {
                Toggle(L("Explicar los pasos en voz alta"), isOn: Binding(get: { store.state.preferences.narrateComputer != false }, set: { store.state.preferences.narrateComputer = $0; if !$0 { store.voice.stop() }; store.save() })).toggleStyle(.switch)
                Text(L("Usa las voces de macOS durante el control para explicar cada acción sin esperar a generar audio. Los pasos también quedan escritos en pantalla.")).font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
            }
        }
    }
    private var autonomy: some View {
        VStack(spacing: 18) {
            card("Trabajo autónomo", icon: "moon.stars") {
                Toggle(L("Preparar trabajo sin esperar mi mensaje"), isOn: preference(\.autonomous)).toggleStyle(.switch).disabled(store.companies.isEmpty)
                Text(L("Aster revisa el objetivo y las tareas de la empresa, prepara una propuesta y te escribe cuando termina. Cada misión usa tu saldo de OpenAI.")).font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
                Picker(L("Empresa"), selection: preference(\.autonomousCompanyID)) {
                    Text(L("Rotar entre mis empresas")).tag(nil as UUID?)
                    ForEach(store.companies) { Text($0.name).tag(Optional($0.id)) }
                }
                HStack {
                    Picker(L("Frecuencia"), selection: preference(\.intervalHours)) { Text(L("Cada hora")).tag(1); Text(L("Cada 3 horas")).tag(3); Text(L("Cada 6 horas")).tag(6); Text(L("Cada 12 horas")).tag(12); Text(L("Cada día")).tag(24) }
                    Stepper(LF("Máximo %d misiones al día", store.state.preferences.dailyLimit), value: preference(\.dailyLimit), in: 1...12)
                }
                Toggle(L("Respetar horas de descanso"), isOn: Binding(get: { store.state.preferences.quietHours ?? false }, set: { store.state.preferences.quietHours = $0; store.save() })).toggleStyle(.switch)
                if store.state.preferences.quietHours == true {
                    HStack { hourPicker("Desde", path: \.quietStart, fallback: 23); hourPicker("Hasta", path: \.quietEnd, fallback: 7) }
                }
                Text(L("Objetivo de las misiones autónomas")).font(.system(size: 11, weight: .medium))
                TextEditor(text: Binding(get: { store.state.preferences.autonomousBrief ?? "" }, set: { store.state.preferences.autonomousBrief = $0; store.save() })).font(.system(size: 12)).frame(height: 75).scrollContentBackground(.hidden).padding(10).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                Text(LF("Misiones iniciadas hoy: %d de %d", store.state.preferences.dailyRuns, store.state.preferences.dailyLimit)).font(.system(size: 11)).foregroundStyle(.secondary)
                if let next = store.nextAutonomous { Text(L("Próxima revisión a partir de:") + " " + next.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11)).foregroundStyle(.secondary) }
                if store.companies.isEmpty { Text(L("Añade una empresa para activar estas misiones.")).font(.system(size: 11)).foregroundStyle(.secondary) }
                Text(L("El trabajo autónomo se pausa cuando una misión falla. Revisa la bandeja antes de volver a activarlo.")).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            card("Siempre cerca", icon: "macwindow.on.rectangle") {
                Text(L("Cerrar la ventana mantiene Aster en la barra de menús. Las revisiones de correo y agenda se realizan cada 15 minutos con el Mac despierto y Aster abierto.")).font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(5)
                Text(L("Los agentes ya iniciados trabajan en OpenAI. Las herramientas locales esperan a que Aster vuelva a estar abierto. Programar trabajo nuevo o revisar cuentas con el Mac apagado requiere un servicio en la nube que todavía no está conectado.")).font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
            }
        }
    }
    private func hourPicker(_ title: String, path: WritableKeyPath<Preferences, Int?>, fallback: Int) -> some View {
        Picker(L(title), selection: Binding(get: { store.state.preferences[keyPath: path] ?? fallback }, set: { store.state.preferences[keyPath: path] = $0; store.save() })) { ForEach(0..<24) { Text(String(format: "%02d:00", $0)).tag($0) } }
    }
    private func card<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Label(L(title), systemImage: icon).font(.system(size: 15, weight: .semibold))
            content().font(.system(size: 12))
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading).frostedSurface(23)
    }
}
