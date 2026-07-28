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
                CardPreviewView(editing: $model.card,
                                ctaTitle: "Create digital card") {
                    Task { await model.submit(into: account) }
                }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                // Explicit entry point for editing — the inline fields above
                // work too, but a labelled button is unmissable.
                Button {
                    focusedField = .fullName
                } label: {
                    Label("Edit fields", systemImage: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
            } header: {
                Text("Your card — tap any line to edit")
            } footer: {
                Text(model.parsedWithAI
                     ? "Fields extracted with Apple Intelligence — edit on the card or in the fields below."
                     : "Fields extracted on-device — edit on the card or in the fields below.")
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
                Text("Your account is created automatically with this email, and your card goes live instantly — share it by QR or link.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
    }
}
