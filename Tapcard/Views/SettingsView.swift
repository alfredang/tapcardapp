import SwiftUI

struct SettingsView: View {
    @Environment(AccountStore.self) private var account
    @Environment(\.openURL) private var openURL

    @State private var showDeleteConfirm = false
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
                LabeledContent("App", value: "Tapcard")
                LabeledContent("Version", value: appVersion)
                Link("Support", destination: Constants.supportURL)
            }

            Section {
                Text("Tapcard turns paper business cards into shareable digital cards. Scanning and text recognition run on-device with VisionKit; your card details sync to your Tapcard account.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
