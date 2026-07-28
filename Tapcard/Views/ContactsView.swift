import SwiftUI

/// Contacts hub — mirrors the Android screen: a Leads inbox (captured from
/// your public cards; save-as-contact or dismiss) and your saved Contacts
/// (full CRUD, synced to the web CRM). Also hosts the QR-scan capture entry.
struct ContactsView: View {
    @Environment(AccountStore.self) private var account

    @State private var section: Section = .contacts
    @State private var leads: [Lead] = []
    @State private var contacts: [Contact] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var editingContact: Contact?
    @State private var showQRScanner = false

    enum Section: String, CaseIterable, Identifiable {
        case contacts = "Contacts"
        case leads = "Leads"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $section) {
                    ForEach(Section.allCases) { s in
                        Text(s == .leads && !leads.isEmpty ? "Leads (\(leads.count))" : s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                list
            }
            .navigationTitle("Contacts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showQRScanner = true } label: { Image(systemName: "qrcode.viewfinder") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editingContact = Contact() } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editingContact) { contact in
                ContactEditSheet(contact: contact) { saved in
                    await save(contact: saved, isNew: contact.id.isEmpty)
                }
            }
            .sheet(isPresented: $showQRScanner) {
                QRScanView { scanned in
                    showQRScanner = false
                    editingContact = scanned
                }
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
        if isLoading && contacts.isEmpty && leads.isEmpty {
            Spacer()
            ProgressView()
            Spacer()
        } else if section == .contacts {
            contactsList
        } else {
            leadsList
        }
    }

    @ViewBuilder
    private var contactsList: some View {
        if contacts.isEmpty {
            emptyState("person.crop.circle.badge.plus", "No contacts yet",
                       "Scan a card's QR code or add a contact by hand.")
        } else {
            List {
                ForEach(contacts) { contact in
                    Button { editingContact = contact } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.displayName).font(.headline)
                            if !contact.subtitle.isEmpty {
                                Text(contact.subtitle).font(.subheadline).foregroundStyle(.secondary)
                            }
                            if !contact.email.isEmpty {
                                Text(contact.email).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await delete(contact: contact) }
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
    private var leadsList: some View {
        if leads.isEmpty {
            emptyState("tray", "No leads yet",
                       "When someone shares their details on your public card, they appear here.")
        } else {
            List {
                ForEach(leads) { lead in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lead.displayName).font(.headline)
                        if !lead.company.isEmpty {
                            Text(lead.company).font(.subheadline).foregroundStyle(.secondary)
                        }
                        if !lead.message.isEmpty {
                            Text(lead.message).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Button("Save as contact") {
                            Task { await saveLead(lead) }
                        }
                        .font(.footnote.weight(.semibold))
                        .padding(.top, 2)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await dismissLead(lead) }
                        } label: { Label("Dismiss", systemImage: "trash") }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
        }
    }

    private func emptyState(_ icon: String, _ title: String, _ message: String) -> some View {
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
        async let c = try? TapcardAPI.fetchContacts(token: token)
        async let l = try? TapcardAPI.fetchLeads(token: token)
        if let fetched = await c { contacts = fetched }
        if let fetched = await l { leads = fetched }
        isLoading = false
    }

    private func save(contact: Contact, isNew: Bool) async {
        guard let token = account.token else { return }
        do {
            if isNew {
                let created = try await TapcardAPI.createContact(token: token, contact)
                contacts.insert(created, at: 0)
            } else {
                let updated = try await TapcardAPI.updateContact(token: token, contact)
                if let idx = contacts.firstIndex(where: { $0.id == updated.id }) {
                    contacts[idx] = updated
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(contact: Contact) async {
        guard let token = account.token else { return }
        do {
            try await TapcardAPI.deleteContact(token: token, id: contact.id)
            contacts.removeAll { $0.id == contact.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveLead(_ lead: Lead) async {
        guard let token = account.token else { return }
        do {
            let created = try await TapcardAPI.createContact(token: token, lead.toContact())
            contacts.insert(created, at: 0)
            try await TapcardAPI.deleteLead(token: token, id: lead.id)
            leads.removeAll { $0.id == lead.id }
            section = .contacts
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func dismissLead(_ lead: Lead) async {
        guard let token = account.token else { return }
        do {
            try await TapcardAPI.deleteLead(token: token, id: lead.id)
            leads.removeAll { $0.id == lead.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Add/edit form for a contact. An empty `id` means "create".
struct ContactEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State var contact: Contact
    let onSave: (Contact) async -> Void
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Person") {
                    TextField("Name", text: $contact.name)
                    TextField("Position", text: $contact.position)
                    TextField("Company", text: $contact.company)
                }
                Section("Reach them") {
                    TextField("Email", text: $contact.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Phone", text: $contact.phone)
                        .keyboardType(.phonePad)
                    TextField("WhatsApp", text: $contact.whatsapp)
                        .keyboardType(.phonePad)
                    TextField("Address", text: $contact.address)
                }
                Section("Notes") {
                    TextField("Notes", text: $contact.notes, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Tags (comma separated)", text: $contact.tags)
                }
            }
            .navigationTitle(contact.id.isEmpty ? "New contact" : "Edit contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isSaving = true
                        Task {
                            await onSave(contact)
                            dismiss()
                        }
                    }
                    .disabled(contact.name.trimmed.isEmpty || isSaving)
                }
            }
        }
    }
}
