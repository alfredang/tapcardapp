import SwiftUI

/// Editable form pre-filled from OCR, with a live native preview of the card
/// on top — every field edit or theme tap re-renders it instantly. The user
/// confirms/corrects, then taps "Create digital card" to publish.
struct ReviewCardView: View {
    @Environment(AccountStore.self) private var account
    @Bindable var model: ScanViewModel
    @FocusState private var focusedField: CardField?

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
                CardPreviewView(card: model.card) { field in
                    focusedField = field
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                Text("Preview")
            } footer: {
                Text(model.parsedWithAI
                     ? "Fields extracted with Apple Intelligence — tap any part of the card to edit it."
                     : "Fields extracted on-device — tap any part of the card to edit it.")
            }

            CardFormFields(card: $model.card, focus: $focusedField)

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
