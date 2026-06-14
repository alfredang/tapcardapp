import SwiftUI
import Observation

/// A digital card the user has created on this device, persisted locally so the
/// Home screen can list previously published cards and re-open their links/QR.
struct SavedCard: Codable, Identifiable, Equatable {
    var id: String
    var fullName: String
    var company: String
    var slug: String
    var url: String
    var createdAt: Date
}

/// App-level state: the signed-in account email and the cards created on this
/// device. Cards persist in UserDefaults; credentials live in the Keychain.
@MainActor
@Observable
final class AccountStore {
    private(set) var email: String?
    private(set) var cards: [SavedCard] = []

    private let cardsKey = "tapcard.savedCards"
    private let emailKey = "tapcard.email"

    init() {
        if DemoSupport.seedCards {
            email = "jordan@lumen.studio"
            cards = DemoSupport.demoSavedCards
            return
        }
        email = UserDefaults.standard.string(forKey: emailKey)
        if let data = UserDefaults.standard.data(forKey: cardsKey),
           let decoded = try? JSONDecoder().decode([SavedCard].self, from: data) {
            cards = decoded.sorted { $0.createdAt > $1.createdAt }
        }
    }

    func record(_ response: OnboardResponse, card: BusinessCard) {
        email = response.email
        UserDefaults.standard.set(response.email, forKey: emailKey)
        KeychainStore.set(response.email, for: "email")
        if let pw = response.password {
            KeychainStore.set(pw, for: "password")
        }

        let saved = SavedCard(
            id: response.card.id,
            fullName: card.fullName.trimmingCharacters(in: .whitespacesAndNewlines),
            company: card.company.trimmingCharacters(in: .whitespacesAndNewlines),
            slug: response.card.slug,
            url: response.card.url,
            createdAt: Date()
        )
        cards.insert(saved, at: 0)
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(cards) {
            UserDefaults.standard.set(data, forKey: cardsKey)
        }
    }
}
