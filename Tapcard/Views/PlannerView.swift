import SwiftUI

/// Planner — mirrors the Android screen: Tasks (follow-ups, reminders,
/// meetings; tap to toggle done) and Appointments, both synced to the CRM.
struct PlannerView: View {
    @Environment(AccountStore.self) private var account

    @State private var section: Section = .tasks
    @State private var tasks: [CRMTask] = []
    @State private var appointments: [Appointment] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var editingTask: TaskDraft?
    @State private var editingAppointment: AppointmentDraft?

    enum Section: String, CaseIterable, Identifiable {
        case tasks = "Tasks"
        case appointments = "Appointments"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $section) {
                    ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                list
            }
            .navigationTitle("Planner")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if section == .tasks { editingTask = TaskDraft() }
                        else { editingAppointment = AppointmentDraft() }
                    } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editingTask) { draft in
                TaskEditSheet(draft: draft) { saved in await save(task: saved) }
            }
            .sheet(item: $editingAppointment) { draft in
                AppointmentEditSheet(draft: draft) { saved in await save(appointment: saved) }
            }
            .task { await reload() }
            .refreshable { await reload() }
            .alert("Something went wrong", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
        }
    }

    @ViewBuilder
    private var list: some View {
        if isLoading && tasks.isEmpty && appointments.isEmpty {
            Spacer(); ProgressView(); Spacer()
        } else if section == .tasks {
            tasksList
        } else {
            appointmentsList
        }
    }

    @ViewBuilder
    private var tasksList: some View {
        if tasks.isEmpty {
            plannerEmpty("checklist", "No tasks yet", "Add follow-ups, reminders and meetings for the people you meet.")
        } else {
            List {
                ForEach(tasks) { task in
                    HStack(spacing: 12) {
                        Button {
                            Task { await toggle(task) }
                        } label: {
                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(task.isDone ? .green : .secondary)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(.headline)
                                .strikethrough(task.isDone)
                                .foregroundStyle(task.isDone ? .secondary : .primary)
                            HStack(spacing: 6) {
                                Text(CRMTask.typeLabel(task.type))
                                if let due = ISO8601.date(from: task.dueAt) {
                                    Text("· due \(due.formatted(date: .abbreviated, time: .shortened))")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editingTask = TaskDraft(task) }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await delete(task: task) }
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
        }
    }

    @ViewBuilder
    private var appointmentsList: some View {
        if appointments.isEmpty {
            plannerEmpty("calendar.badge.plus", "No appointments yet", "Schedule meetings with your leads and contacts.")
        } else {
            List {
                ForEach(appointments) { appt in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appt.name).font(.headline)
                        if let start = ISO8601.date(from: appt.startAt) {
                            Text(start.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text(Appointment.statusLabel(appt.status))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(appt.status == "CONFIRMED" ? .green : .secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editingAppointment = AppointmentDraft(appt) }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await delete(appointment: appt) }
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
        }
    }

    private func plannerEmpty(_ icon: String, _ title: String, _ message: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: icon).font(.largeTitle).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // ─── Data ───────────────────────────────────────────────────────────────

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func reload() async {
        guard let token = account.token else { return }
        isLoading = true
        async let t = try? TapcardAPI.fetchTasks(token: token)
        async let a = try? TapcardAPI.fetchAppointments(token: token)
        if let fetched = await t { tasks = fetched }
        if let fetched = await a { appointments = fetched }
        isLoading = false
    }

    private func toggle(_ task: CRMTask) async {
        guard let token = account.token else { return }
        let next = task.isDone ? "TODO" : "DONE"
        do {
            let updated = try await TapcardAPI.setTaskStatus(token: token, id: task.id, status: next)
            if let idx = tasks.firstIndex(where: { $0.id == updated.id }) { tasks[idx] = updated }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(task draft: TaskDraft) async {
        guard let token = account.token else { return }
        let dueAt = draft.hasDue ? ISO8601.string(from: draft.dueDate) : nil
        do {
            if draft.id.isEmpty {
                let created = try await TapcardAPI.createTask(token: token, title: draft.title, type: draft.type, dueAt: dueAt)
                tasks.insert(created, at: 0)
            } else {
                let updated = try await TapcardAPI.updateTask(token: token, id: draft.id, title: draft.title, type: draft.type, dueAt: dueAt)
                if let idx = tasks.firstIndex(where: { $0.id == updated.id }) { tasks[idx] = updated }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(task: CRMTask) async {
        guard let token = account.token else { return }
        do {
            try await TapcardAPI.deleteTask(token: token, id: task.id)
            tasks.removeAll { $0.id == task.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(appointment draft: AppointmentDraft) async {
        guard let token = account.token else { return }
        let start = ISO8601.string(from: draft.startDate)
        let end = ISO8601.string(from: draft.endDate)
        do {
            if draft.id.isEmpty {
                let created = try await TapcardAPI.createAppointment(
                    token: token, name: draft.name, email: draft.email,
                    startAt: start, endAt: end, notes: draft.notes)
                appointments.insert(created, at: 0)
            } else {
                let updated = try await TapcardAPI.updateAppointment(
                    token: token, id: draft.id, name: draft.name, email: draft.email,
                    startAt: start, endAt: end, notes: draft.notes)
                if let idx = appointments.firstIndex(where: { $0.id == updated.id }) { appointments[idx] = updated }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(appointment: Appointment) async {
        guard let token = account.token else { return }
        do {
            try await TapcardAPI.deleteAppointment(token: token, id: appointment.id)
            appointments.removeAll { $0.id == appointment.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// ─── Edit sheets ────────────────────────────────────────────────────────────

/// Editable snapshot of a task for the add/edit sheet.
struct TaskDraft: Identifiable {
    var id = ""
    var title = ""
    var type = "FOLLOW_UP"
    var hasDue = false
    var dueDate = Date()

    init() {}
    init(_ task: CRMTask) {
        id = task.id
        title = task.title
        type = task.type
        if let due = ISO8601.date(from: task.dueAt) {
            hasDue = true
            dueDate = due
        }
    }
}

struct TaskEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: TaskDraft
    let onSave: (TaskDraft) async -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("What needs doing?", text: $draft.title)
                Picker("Type", selection: $draft.type) {
                    ForEach(CRMTask.types, id: \.self) { Text(CRMTask.typeLabel($0)).tag($0) }
                }
                Toggle("Due date", isOn: $draft.hasDue)
                if draft.hasDue {
                    DatePicker("Due", selection: $draft.dueDate)
                }
            }
            .navigationTitle(draft.id.isEmpty ? "New task" : "Edit task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await onSave(draft); dismiss() }
                    }
                    .disabled(draft.title.trimmed.isEmpty)
                }
            }
        }
    }
}

/// Editable snapshot of an appointment for the add/edit sheet.
struct AppointmentDraft: Identifiable {
    var id = ""
    var name = ""
    var email = ""
    var notes = ""
    var startDate = Date()
    var endDate = Date().addingTimeInterval(3600)

    init() {}
    init(_ appt: Appointment) {
        id = appt.id
        name = appt.name
        email = appt.email ?? ""
        notes = appt.notes ?? ""
        startDate = ISO8601.date(from: appt.startAt) ?? Date()
        endDate = ISO8601.date(from: appt.endAt) ?? Date().addingTimeInterval(3600)
    }
}

struct AppointmentEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: AppointmentDraft
    let onSave: (AppointmentDraft) async -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Who") {
                    TextField("Name", text: $draft.name)
                    TextField("Email (optional)", text: $draft.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                Section("When") {
                    DatePicker("Starts", selection: $draft.startDate)
                    DatePicker("Ends", selection: $draft.endDate)
                }
                Section("Notes") {
                    TextField("Notes (optional)", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(draft.id.isEmpty ? "New appointment" : "Edit appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await onSave(draft); dismiss() }
                    }
                    .disabled(draft.name.trimmed.isEmpty || draft.endDate <= draft.startDate)
                }
            }
        }
    }
}
