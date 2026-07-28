import SwiftUI

struct SettingsView: View {
    @Environment(AccountStore.self) private var account
    @Environment(\.openURL) private var openURL

    @State private var showDeleteConfirm = false
    @State private var showFeedback = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        Form {
            Section("Account") {
                if let name = account.userName, !name.isEmpty {
                    LabeledContent("Name", value: name)
                }
                if let email = account.email {
                    LabeledContent("Signed in as", value: email)
                } else {
                    Text("No account yet — scan a card to create one.")
                        .foregroundStyle(.secondary)
                }
            }

            if account.isSignedIn {
                Section {
                    Button("Sign Out", role: .destructive) {
                        account.signOut()
                    }
                } footer: {
                    Text("Signs out on this device. Your cards, contacts and planner stay in your account.")
                }
            }

            if account.email != nil {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        if isDeleting {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Deleting account…")
                            }
                        } else {
                            Text("Delete Account")
                        }
                    }
                    .disabled(isDeleting)
                } footer: {
                    Text("Permanently deletes your Tapcard account and published cards. This cannot be undone.")
                }
            }

            Section {
                aiRow("Smart card parsing", available: parsingAvailable)
                if !parsingAvailable {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        Label("Enable in Settings", systemImage: "gear")
                    }
                }
            } header: {
                Text("Apple Intelligence")
            } footer: {
                Text(parsingAvailable
                     ? "Apple Intelligence is active: scanned cards are parsed by the on-device model."
                     : "Turn on Apple Intelligence (Settings → Apple Intelligence & Siri) and wait for the model download. It powers smarter card parsing — everything runs on-device.")
            }

            Section("About") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tapcard")
                        .font(.headline)
                    Text("Tapcard turns any paper business card into a live digital card. Scan a card and it's read entirely on-device; review the details, pick one of 20 themes, and publish a shareable page with its own link and QR code. Edit everything right on the card, capture leads from people who view it, keep contacts and follow-ups organised in the built-in planner, and watch views, taps and leads in Analytics — all from your phone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                LabeledContent("Version", value: appVersion)
            }

            Section("Developer") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tertiary Infotech Academy Pte Ltd")
                        .font(.subheadline.weight(.medium))
                    Link("tertiaryinfotech.com", destination: Constants.supportURL)
                        .font(.footnote)
                }
                .padding(.vertical, 2)
                Button {
                    showFeedback = true
                } label: {
                    Label("Send Feedback", systemImage: "bubble.left.and.bubble.right.fill")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete your Tapcard account?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive, action: deleteAccount)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account and all cards you've published. This cannot be undone.")
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackSheet()
        }
        .alert("Couldn't delete account", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })
    }

    private func deleteAccount() {
        isDeleting = true
        Task {
            do {
                try await account.deleteAccount()
            } catch {
                deleteError = error.localizedDescription
            }
            isDeleting = false
        }
    }

    private func aiRow(_ title: String, available: Bool) -> some View {
        HStack {
            Label(title, systemImage: "sparkles")
            Spacer()
            Text(available ? "On" : "Off")
                .foregroundStyle(available ? Theme.success : .secondary)
                .fontWeight(.medium)
        }
    }

    private var parsingAvailable: Bool {
        if #available(iOS 26.0, *) { AIContactExtractor.isAvailable } else { false }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}


/// Feedback dialog — Title + Message, sent to the Tertiary Infotech WhatsApp
/// Business line. The wa.me link works whether or not WhatsApp is installed.
struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var title = ""
    @State private var message = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("What's this about?", text: $title)
                }
                Section("Message") {
                    TextEditor(text: $message)
                        .frame(minHeight: 130)
                        .scrollContentBackground(.hidden)
                }
                Section {
                    Button {
                        send()
                    } label: {
                        Label("Send via WhatsApp", systemImage: "paperplane.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(title.trimmed.isEmpty && message.trimmed.isEmpty)
                } footer: {
                    Text("Opens WhatsApp to our support line, +65 8866 6375.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func send() {
        var components = URLComponents(string: "https://wa.me/6588666375")!
        let body = "Tapcard feedback — \(title.trimmed)\n\n\(message.trimmed)"
        components.queryItems = [URLQueryItem(name: "text", value: body)]
        if let url = components.url { openURL(url) }
        dismiss()
    }
}
