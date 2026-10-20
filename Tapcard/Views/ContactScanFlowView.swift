import SwiftUI

/// Scan someone else's paper business card into Contacts: one photo, read
/// on-device the same way as your own card, then the contact form pre-filled
/// to check and save. Synced to the web CRM like any other contact.
struct ContactScanFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AccountStore.self) private var account
    /// Called with the contact as the server saved it.
    var onSaved: (Contact) -> Void = { _ in }

    @State private var stage: Stage = .scanning

    enum Stage: Equatable {
        case scanning
        case reading
        case review(Contact)
    }

    var body: some View {
        switch stage {
        case .scanning:
            CardScannerView(
                onScan: { image in Task { await read(image) } },
                onCancel: { dismiss() }
            )
            .ignoresSafeArea()
        case .reading:
            VStack(spacing: 18) {
                ProgressView().controlSize(.large)
                Text("Reading the card…").font(.headline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
        case .review(let contact):
            // The form's Save and Cancel both dismiss this whole flow.
            ContactEditSheet(contact: contact) { try await save($0) }
        }
    }

    private func read(_ image: UIImage) async {
        stage = .reading
        // A card that can't be read still opens the form, empty, to fill in.
        var contact = Contact()
        if let cgImage = image.cgImage, let (card, _) = try? await ScanViewModel.read(cgImage) {
            contact = card.toContact()
        }
        stage = .review(contact)
    }

    private func save(_ contact: Contact) async throws {
        guard let token = account.token else {
            throw APIError.server("Sign in to save contacts.")
        }
        let created = try await TapcardAPI.createContact(token: token, contact)
        onSaved(created)
    }
}
