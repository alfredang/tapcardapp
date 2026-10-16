import SwiftUI

struct SettingsView: View {
    @Environment(AccountStore.self) private var account
    @Environment(\.openURL) private var openURL

    @State private var showDeleteConfirm = false
    @State private var showFeedback = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var biometricError: String?
    @State private var changingBiometrics = false
    @State private var preferenceError: String?

    var body: some View {
        Form {
            if let card = primaryCard {
                Section {
                    NavigationLink {
                        CardDesignSettingsView(cardID: card.id)
                    } label: {
                        HStack {
                            Label("Card design", systemImage: "paintpalette")
                            Spacer()
                            Text(design(of: card).designName)
                                .foregroundStyle(.secondary)
                            CardDesignBanner(theme: design(of: card))
                                .frame(width: 34, height: 22)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                    }
                    NavigationLink {
                        EditCardView(saved: card)
                    } label: {
                        Label("Edit card details", systemImage: "pencil")
                    }
                } header: {
                    Text("Your card")
                } footer: {
                    Text("Designs, colours and details update your live card on the web instantly.")
                }
            }

            Section {
                Picker(selection: Binding(
                    get: { account.preferences.countryCode },
                    set: { code in Task { preferenceError = await account.updatePreferences(countryCode: code) } })
                ) {
                    ForEach(countries) { country in
                        Text("\(country.label)  +\(country.code)").tag(country.code)
                    }
                } label: {
                    Label("Country code", systemImage: "globe.asia.australia")
                }
                .pickerStyle(.navigationLink)

                Picker(selection: Binding(
                    get: { account.preferences.qrMode },
                    set: { mode in Task { preferenceError = await account.updatePreferences(qrMode: mode) } })
                ) {
                    ForEach(QRMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                } label: {
                    Label("QR code opens", systemImage: "qrcode")
                }

                if let card = primaryCard {
                    whatsappStatus(for: card)
                }
            } header: {
                Text("Sharing")
            } footer: {
                Text("Local numbers on your card get +\(account.preferences.countryCode) added, so anyone who scans your QR lands in a WhatsApp chat with you. Synced with your account — also at tapcard.tertiaryinfotech.com/settings.")
            }

            if account.isSignedIn {
                Section {
                    Toggle(isOn: Binding(
                        get: { account.biometricEnabled },
                        set: { enabled in
                            changingBiometrics = true
                            Task {
                                do { try await account.setBiometricEnabled(enabled) }
                                catch { biometricError = error.localizedDescription }
                                changingBiometrics = false
                            }
                        })) {
                        Label("Log in with \(BiometricAuthService.label)",
                              systemImage: BiometricAuthService.label == "Touch ID" ? "touchid" : "faceid")
                    }
                    .disabled(changingBiometrics || (!account.biometricEnabled && !BiometricAuthService.isAvailable))
                } header: { Text("Security") }
                footer: { Text("Tapcard locks when you leave the app and opens with \(BiometricAuthService.label).") }
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
                    Text("Tapcard turns any paper business card into a live digital card. Scan a card and it's read entirely on-device; review the details, pick one of 20 illustrated designs, and publish a shareable page with its own link and QR code. Edit everything right on the card, capture leads from people who view it, keep contacts and follow-ups organised in the built-in planner, and watch views, taps and leads in Analytics — all from your phone.")
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
        .alert("Biometric login", isPresented: Binding(get: { biometricError != nil }, set: { if !$0 { biometricError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(biometricError ?? "") }
        .alert("Couldn't save setting", isPresented: Binding(get: { preferenceError != nil }, set: { if !$0 { preferenceError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(preferenceError ?? "") }
        .alert("Couldn't delete account", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    private var primaryCard: SavedCard? { account.cards.first }

    private func design(of card: SavedCard) -> CardTheme { card.details?.theme ?? .modern }

    /// The picker list, plus the saved code if it isn't one of ours.
    private var countries: [DialCountry] {
        let code = account.preferences.countryCode
        return DialCountry.all.contains { $0.code == code } ? DialCountry.all : [DialCountry.named(code)] + DialCountry.all
    }

    /// Which number the WhatsApp QR chats with — the thing that was broken
    /// when local numbers lacked a country code — so it's checkable at a glance.
    @ViewBuilder
    private func whatsappStatus(for card: SavedCard) -> some View {
        let code = account.preferences.countryCode
        if let details = card.details, let number = WhatsAppLink.number(for: details, countryCode: code) {
            LabeledContent {
                Text(PhoneNumber.display(digits: number, countryCode: code))
                    .foregroundStyle(.secondary)
            } label: {
                HStack(spacing: 8) {
                    WhatsAppGlyph().frame(width: 18, height: 18)
                    Text("WhatsApp chats with")
                }
            }
        } else {
            NavigationLink {
                EditCardView(saved: card)
            } label: {
                Label("Add a mobile or WhatsApp number", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.orange)
            }
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
