import SwiftUI

struct SettingsView: View {
    @Environment(AccountStore.self) private var account

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
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
