import SwiftUI

struct SettingsView: View {
    @Environment(AccountStore.self) private var account

    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        Form {
            Section("Account") {
                if let email = account.email {
                    LabeledContent("Signed in as", value: email)
                } else {
                    Text("No account yet — scan a card to create one.")
                        .foregroundStyle(.secondary)
                }
                Link("Manage cards & leads on the web", destination: Constants.apiBaseURL)
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

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
