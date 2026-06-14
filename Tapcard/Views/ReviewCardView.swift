import SwiftUI

/// Editable form pre-filled from OCR. The user confirms/corrects fields, then
/// taps "Create digital card" to publish.
struct ReviewCardView: View {
    @Environment(AccountStore.self) private var account
    @Bindable var model: ScanViewModel

    var body: some View {
        Form {
            if let error = model.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                }
            }

            Section("Identity") {
                field("Full name", text: $model.card.fullName, icon: "person", required: true)
                field("Job title", text: $model.card.jobTitle, icon: "briefcase")
                field("Company", text: $model.card.company, icon: "building.2")
            }

            Section("Contact") {
                field("Email", text: $model.card.email, icon: "envelope",
                      keyboard: .emailAddress, required: true)
                field("Mobile", text: $model.card.mobile, icon: "iphone", keyboard: .phonePad)
                field("Office phone", text: $model.card.officePhone, icon: "phone", keyboard: .phonePad)
                field("Website", text: $model.card.website, icon: "globe", keyboard: .URL)
                field("Address", text: $model.card.address, icon: "mappin.and.ellipse")
            }

            Section("Social") {
                field("LinkedIn", text: $model.card.linkedin, icon: "link")
                field("Twitter / X", text: $model.card.twitter, icon: "at")
            }

            Section("Design") {
                Picker("Theme", selection: $model.card.theme) {
                    ForEach(CardTheme.allCases) { theme in
                        Text(theme.label).tag(theme)
                    }
                }
            }

            Section {
                Button {
                    Task { await model.submit(into: account) }
                } label: {
                    Text("Create digital card")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .disabled(!model.card.isValid)
            } footer: {
                Text("Your account is created automatically with this email, and the card is published to tapcard.tertiaryinfotech.com.")
            }
        }
    }

    @ViewBuilder
    private func field(
        _ title: String,
        text: Binding<String>,
        icon: String,
        keyboard: UIKeyboardType = .default,
        required: Bool = false
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            TextField(required ? "\(title) (required)" : title, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress || keyboard == .URL ? .never : .words)
                .autocorrectionDisabled(keyboard == .emailAddress || keyboard == .URL)
        }
    }
}
