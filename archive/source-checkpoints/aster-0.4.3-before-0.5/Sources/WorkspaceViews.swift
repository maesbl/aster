import SwiftUI

struct TaskBoardView: View {
    @EnvironmentObject var store: AsterStore
    @State private var adding = false
    @State private var completed = false
    @State private var companyID: UUID?
    @State private var query = ""
    @State private var section = "Aster"
    @State private var addingAlert = false
    private var tasks: [WorkTask] {
        store.state.tasks.filter { (completed || !$0.done) && (companyID == nil || $0.companyID == companyID) && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack { VStack(alignment: .leading, spacing: 8) { Text(L("Ideas que avanzan.")).font(.system(size: 30, weight: .semibold, design: .rounded)); Text(L("Próximos pasos para ti y para tus empresas.")).font(.system(size: 12)).foregroundStyle(.secondary) }; Spacer(); GlassAction(title: section == "Avisos" ? "Nuevo aviso" : "Nueva tarea", symbol: "plus", prominent: true) { if section == "Avisos" { addingAlert = true } else { adding = true } }.opacity(section == "Apple" ? 0 : 1).disabled(section == "Apple") }
                Picker(L("Listas"), selection: $section) { Text("Aster").tag("Aster"); Text("Apple").tag("Apple"); Text(L("Avisos")).tag("Avisos") }.pickerStyle(.segmented).frame(maxWidth: 330)
                if section == "Aster" {
                HStack {
                    TextField(L("Buscar tareas…"), text: $query).textFieldStyle(.roundedBorder)
                    Picker(L("Empresa"), selection: $companyID) { Text(L("Todas las empresas")).tag(nil as UUID?); ForEach(store.companies) { Text($0.name).tag(Optional($0.id)) } }.frame(width: 200)
                    Toggle(L("Terminadas"), isOn: $completed).toggleStyle(.switch)
                }.font(.system(size: 11))
                if tasks.isEmpty { WorkspaceEmpty(symbol: "checklist", title: "Un buen siguiente paso", detail: "Añade una tarea o pide al equipo que guarde los próximos pasos de una misión.") }
                ForEach(tasks) { item in
                    HStack(alignment: .top, spacing: 14) {
                        Button { store.toggleTask(item.id) } label: { Image(systemName: item.done ? "checkmark.circle.fill" : "circle").font(.system(size: 20, weight: .light)).foregroundStyle(item.done ? Color.accentColor : .secondary) }.buttonStyle(.plain).accessibilityLabel(item.done ? L("Marcar pendiente") : L("Marcar terminada"))
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.title).font(.system(size: 13, weight: .medium)).strikethrough(item.done).textSelection(.enabled)
                            HStack(spacing: 8) {
                                if let company = store.state.companies.first(where: { $0.id == item.companyID }) { Text(company.name) } else { Text(L("Personal")) }
                                if let due = item.due { Text(due.formatted(date: .abbreviated, time: .omitted)).foregroundStyle(due < Date() && !item.done ? Color.orange : .secondary) }
                            }.font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 10)
                        if let id = item.missionID { GlassIconButton(symbol: "bubble.left", title: "Ver misión") { store.openMission(id) } }
                        if !item.done { GlassAction(title: "Trabajar en ello", symbol: "sparkle") { store.executeTask(item) }.disabled(store.busy) }
                    }.padding(19).frostedSurface(20)
                }
                } else if section == "Apple" { appleReminders }
                else { alerts }
            }.padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 25)
        }.sheet(isPresented: $adding) { TaskForm(initialCompanyID: companyID) }
         .sheet(isPresented: $addingAlert) { AlertForm() }
         .onChange(of: section) { _, new in if new == "Apple" { Task { await store.refreshReminders() } } }
    }
    private var appleReminders: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text(L(store.remindersStatus)).font(.system(size: 11)).foregroundStyle(.secondary); Spacer(); GlassAction(title: store.state.preferences.watchReminders == true ? "Actualizar" : "Conectar Recordatorios", symbol: "arrow.clockwise") { if store.state.preferences.watchReminders == true { Task { await store.refreshReminders() } } else { store.connectReminders() } } }
            Toggle(L("Terminadas"), isOn: $completed).toggleStyle(.switch).font(.system(size: 11))
            if store.reminders.isEmpty { WorkspaceEmpty(symbol: "checklist", title: "Tus recordatorios de Apple", detail: "Conecta Recordatorios para ver tus listas aquí. Después puedes pedirle a Aster que cree o complete tareas.") }
            ForEach(store.reminders.filter { completed || !$0.completed }) { reminder in
                HStack(alignment: .top, spacing: 13) {
                    Button { store.completeReminder(reminder.id) } label: { Image(systemName: reminder.completed ? "checkmark.circle.fill" : "circle").font(.system(size: 20, weight: .light)) }.buttonStyle(.plain).accessibilityLabel(reminder.completed ? L("Marcar pendiente") : L("Marcar terminada"))
                    VStack(alignment: .leading, spacing: 7) { Text(reminder.title).font(.system(size: 13, weight: .medium)).strikethrough(reminder.completed); if !reminder.notes.isEmpty { Text(reminder.notes).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(3) }; HStack { Text(reminder.list); if let due = reminder.due { Text(due.formatted(date: .abbreviated, time: .shortened)) } }.font(.system(size: 10)).foregroundStyle(.secondary) }; Spacer()
                }.padding(18).frostedSurface(20)
            }
        }
    }
    private var alerts: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !store.state.preferences.notifications { HStack { Text(L("Activa las notificaciones para recibir tus avisos.")).font(.system(size: 11)); Spacer(); Button(L("Permitir avisos"), action: store.requestNotifications) }.padding(17).frostedSurface(18) }
            if store.state.alerts.isEmpty { WorkspaceEmpty(symbol: "bell", title: "Te lo recordaré.", detail: "Crea un aviso con fecha o pídeselo en la conversación. También puedes programarlo cada día o cada semana.") }
            ForEach(store.state.alerts.sorted { $0.date < $1.date }) { alert in
                HStack(spacing: 13) { Image(systemName: alert.recurrence == "none" ? "bell" : "repeat").font(.system(size: 18, weight: .light)); VStack(alignment: .leading, spacing: 7) { Text(alert.text).font(.system(size: 13, weight: .medium)); Text(alert.date.formatted(date: .abbreviated, time: .shortened) + " · " + L(alert.recurrence == "daily" ? "Cada día" : alert.recurrence == "weekly" ? "Cada semana" : "Una vez")).font(.system(size: 10)).foregroundStyle(.secondary); Text(L(alert.scheduled ? "Programado en macOS" : "Pendiente de permiso")).font(.system(size: 10)).foregroundStyle(.secondary) }; Spacer(); GlassIconButton(symbol: "xmark", title: "Cancelar aviso") { store.cancelAlert(alert.id) } }.padding(19).frostedSurface(20)
            }
        }
    }

}

struct TaskForm: View {
    @EnvironmentObject var store: AsterStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var companyID: UUID?
    @State private var agentID = "director"
    @State private var hasDue = false
    @State private var due = Date().addingTimeInterval(86400)
    init(initialCompanyID: UUID?) { _companyID = State(initialValue: initialCompanyID) }
    var body: some View {
        VStack(alignment: .leading, spacing: 21) {
            HStack { Text(L("Un siguiente paso.")).font(.system(size: 26, weight: .semibold, design: .rounded)); Spacer(); GlassIconButton(symbol: "xmark", title: "Cerrar") { dismiss() } }
            TextField(L("¿Qué hay que hacer?"), text: $title, axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder)
            Picker(L("Empresa"), selection: $companyID) { Text(L("Personal")).tag(nil as UUID?); ForEach(store.companies) { Text($0.name).tag(Optional($0.id)) } }
            Picker(L("Especialista"), selection: $agentID) { ForEach(store.state.specialists) { Text($0.name + " · " + L($0.role)).tag($0.id) } }
            Toggle(L("Añadir fecha"), isOn: $hasDue).toggleStyle(.switch)
            if hasDue { DatePicker(L("Para el"), selection: $due, displayedComponents: .date) }
            HStack { Spacer(); GlassAction(title: "Guardar tarea", symbol: "checkmark", prominent: true) { store.addTask(title, companyID: companyID, specialistID: agentID, due: hasDue ? due : nil); dismiss() }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.font(.system(size: 12)).padding(28).frame(width: 480).background(AmbientBackdrop(tint: store.agent.style.tint.color))
    }
}

struct AlertForm: View {
    @EnvironmentObject var store: AsterStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var date = Date().addingTimeInterval(3600)
    @State private var recurrence = "none"
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack { Text(L("Te lo recordaré.")).font(.system(size: 26, weight: .semibold, design: .rounded)); Spacer(); GlassIconButton(symbol: "xmark", title: "Cerrar") { dismiss() } }
            TextField(L("¿Qué quieres que te recuerde?"), text: $text, axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder)
            DatePicker(L("Cuándo"), selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
            Picker(L("Repetir"), selection: $recurrence) { Text(L("Una vez")).tag("none"); Text(L("Cada día")).tag("daily"); Text(L("Cada semana")).tag("weekly") }
            Text(L("macOS entrega el aviso a la hora programada. Puedes verlo y cancelarlo en Tareas → Avisos.")).font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
            HStack { Spacer(); GlassAction(title: "Guardar aviso", symbol: "bell.badge", prominent: true) { store.addAlert(text: text, date: date, recurrence: recurrence); dismiss() }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.font(.system(size: 12)).padding(28).frame(width: 490).background(AmbientBackdrop(tint: store.agent.style.tint.color))
    }
}

struct MemoryView: View {
    @EnvironmentObject var store: AsterStore
    @State private var text = ""
    @State private var companyID: UUID?
    @State private var editing: MemoryEntry?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) { Text(L("Que te conozca mejor.")).font(.system(size: 30, weight: .semibold, design: .rounded)); Text(L("Tus preferencias, tu contexto y las cosas que merece recordar.")).font(.system(size: 12)).foregroundStyle(.secondary) }
                VStack(alignment: .leading, spacing: 13) {
                    Text(L("Añadir un recuerdo")).font(.system(size: 14, weight: .semibold))
                    TextEditor(text: $text).font(.system(size: 13)).scrollContentBackground(.hidden).frame(height: 85).padding(10).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                    HStack {
                        Picker(L("Contexto"), selection: $companyID) { Text(L("Personal · todas las misiones")).tag(nil as UUID?); ForEach(store.companies) { Text($0.name).tag(Optional($0.id)) } }.frame(maxWidth: 300)
                        Spacer(); GlassAction(title: "Recordar", symbol: "plus") { store.addMemory(text, companyID: companyID); if store.notice.isEmpty { text = "" } }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }.padding(22).frostedSurface(23)
                Text(L(store.settings.useMemory ? "La memoria se incluye en tus misiones. Los recuerdos de empresa solo se usan en esa empresa." : "La memoria está desactivada. Puedes activarla en Ajustes.")).font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
                if store.state.memories.isEmpty { WorkspaceEmpty(symbol: "brain", title: "Un poco más de ti", detail: "Guarda cómo te gusta trabajar, tus objetivos o contexto útil. También puedes permitir que recuerde lo que le pidas en Ajustes.") }
                ForEach(store.state.memories) { entry in
                    VStack(alignment: .leading, spacing: 13) {
                        Text(entry.text).font(.system(size: 13)).lineSpacing(4).textSelection(.enabled)
                        HStack {
                            Text(store.state.companies.first { $0.id == entry.companyID }?.name ?? L("Personal")).font(.system(size: 10)).foregroundStyle(.secondary)
                            Spacer(); Button(L("Editar")) { editing = entry }; Button(L("Eliminar")) { store.removeMemory(entry.id) }
                        }.font(.system(size: 11)).glassControl()
                    }.padding(20).frostedSurface(21)
                }
            }.padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 25)
        }.sheet(item: $editing) { entry in MemoryEditor(entry: entry) }
    }
}

struct MemoryEditor: View {
    @EnvironmentObject var store: AsterStore
    @Environment(\.dismiss) private var dismiss
    @State var entry: MemoryEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(L("Editar recuerdo")).font(.system(size: 24, weight: .semibold, design: .rounded))
            TextEditor(text: $entry.text).font(.system(size: 13)).frame(height: 180).scrollContentBackground(.hidden).padding(12).frostedSurface(16)
            HStack { Button(L("Cancelar")) { dismiss() }; Spacer(); GlassAction(title: "Guardar", symbol: "checkmark", prominent: true) { store.updateMemory(entry); dismiss() }.disabled(entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(26).frame(width: 480).background(AmbientBackdrop(tint: store.agent.style.tint.color))
    }
}

struct RenameMissionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: AsterStore
    let mission: Mission
    @State var title: String
    init(mission: Mission) { self.mission = mission; _title = State(initialValue: mission.title) }
    var body: some View {
        VStack(alignment: .leading, spacing: 21) {
            Text(L("Renombrar misión")).font(.system(size: 24, weight: .semibold, design: .rounded))
            TextField(L("Nombre"), text: $title).textFieldStyle(.roundedBorder)
            HStack { Button(L("Cancelar")) { dismiss() }; Spacer(); GlassAction(title: "Guardar", symbol: "checkmark", prominent: true) { store.renameMission(mission.id, title: title); dismiss() }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(26).frame(width: 460).background(AmbientBackdrop(tint: store.agent.style.tint.color))
    }
}

struct WorkspaceEmpty: View {
    var symbol: String
    var title: String
    var detail: String
    var body: some View {
        VStack(spacing: 14) { Image(systemName: symbol).font(.system(size: 28, weight: .light)).foregroundStyle(.secondary); Text(L(title)).font(.system(size: 20, weight: .medium, design: .rounded)); Text(L(detail)).font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(4).frame(maxWidth: 400) }.padding(36).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
