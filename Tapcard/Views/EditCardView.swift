import SwiftUI

/// In-app editor for a published card — the mobile-first "revert and edit"
/// loop. Same shared form + live preview as the scan flow; saving PATCHes the
/// backend and refreshes the local list, so the web card updates instantly.
struct EditCardView: View {
    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss

    let cardID: String
    @State private var card: BusinessCard
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: CardField?

    init(saved: SavedCard) {
        cardID = saved.id
        var initial = saved.details ?? BusinessCard()
        if initial.fullName.trimmed.isEmpty { initial.fullName = saved.fullName }
        if initial.company.trimmed.isEmpty { initial.company = saved.company }
        _card = State(initialValue: initial)
    }

    var body: some View {
        Form {
            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                }
            }

            Section {
                CardPreviewView(editing: $card)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } header: {
                Text("Your card — tap any line to edit")
            } footer: {
                Text("Edit directly on the card; more fields below.")
            }

            CardFormFields(card: $card, focus: $focusedField)

            Section {
                Button {
                    save()
                } label: {
                    HStack(spacing: 8) {
                        if isSaving { ProgressView() }
                        Text("Save changes").font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isSaving || !card.isValid)
            } footer: {
                Text("Changes publish immediately to your live card.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Edit card")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() {
        guard let token = account.token else {
            errorMessage = "You're signed out. Sign in again to edit."
            return
        }
        errorMessage = nil
        isSaving = true
        Task {
            do {
                try await TapcardAPI.updateCard(token: token, id: cardID, card: card)
                await account.refreshServerCards()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
