import SwiftUI

/// Editable form pre-filled from OCR, with a live native preview of the card
/// on top — every field edit or theme tap re-renders it instantly. The user
/// confirms/corrects, then taps "Create digital card" to publish.
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

            Section {
                CardPreviewView(card: model.card)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } header: {
                Text("Preview")
            } footer: {
                Text(model.parsedWithAI
                     ? "Fields extracted with Apple Intelligence — review before publishing."
                     : "Fields extracted on-device — review before publishing.")
            }

            CardFormFields(card: $model.card)

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
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
    }
}
