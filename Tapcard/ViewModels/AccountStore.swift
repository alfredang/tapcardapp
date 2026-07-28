import SwiftUI
import Observation

/// A digital card the user has created on this device, persisted locally so the
/// Home screen can list previously published cards and re-open their links/QR.
struct SavedCard: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var fullName: String
    var company: String
    var slug: String
    var url: String
    var createdAt: Date
    /// Full field set + theme, for the native preview and in-app editor.
    /// Optional so cards persisted by older builds keep decoding.
    var details: BusinessCard?
}

/// App-level state: the signed-in account email and the cards created on this
/// device. Cards persist in UserDefaults; credentials live in the Keychain.
@MainActor
@Observable
final class AccountStore {
    private(set) var email: String?
    private(set) var cards: [SavedCard] = []

    /// Bearer token for the signed-in session (nil = signed out). Mirrors the
    /// Android app: the welcome/auth flow gates the app until a token exists.
    private(set) var token: String?
    private(set) var userName: String?

    var isSignedIn: Bool { token != nil }

    private let cardsKey = "tapcard.savedCards"
    private let emailKey = "tapcard.email"

    init() {
        if DemoSupport.seedCards {
            email = "jordan@lumen.studio"
            token = "demo-token"
            userName = "Jordan Avery"
            cards = DemoSupport.demoSavedCards
            return
        }
        email = UserDefaults.standard.string(forKey: emailKey)
        token = KeychainStore.get("token")
        userName = UserDefaults.standard.string(forKey: "tapcard.userName")
        if let data = UserDefaults.standard.data(forKey: cardsKey),
           let decoded = try? JSONDecoder().decode([SavedCard].self, from: data) {
            cards = decoded.sorted { $0.createdAt > $1.createdAt }
        }
    }

    /// Store a successful login / register / OTP-verify session.
    func startSession(_ result: AuthResult) {
        token = result.token
        userName = result.name
        email = result.email ?? email
        KeychainStore.set(result.token, for: "token")
        if let email { UserDefaults.standard.set(email, forKey: emailKey) }
        if let name = result.name { UserDefaults.standard.set(name, forKey: "tapcard.userName") }
        Task { await refreshServerCards() }
    }

    /// Pull the account's published cards from the backend so Home lists them
    /// on any device, not just the one that created them.
    func refreshServerCards() async {
        guard let token else { return }
        guard let server = try? await TapcardAPI.fetchCards(token: token) else { return }
        let mapped = server.map { c in
            SavedCard(id: c.id, fullName: c.fullName, company: c.company ?? "",
                      slug: c.slug ?? "", url: c.publicURL, createdAt: Date(),
                      details: c.asBusinessCard)
        }
        // Server is the source of truth when signed in; keep local-only cards
        // (created before sign-in) that the server doesn't know about.
        let serverIds = Set(mapped.map(\.id))
        cards = mapped + cards.filter { !serverIds.contains($0.id) }
        persist()
    }

    /// Delete a card on the server, then locally. Returns an error message to
    /// surface, or nil on success. A server "Not found" (a local-only card)
    /// still removes the local copy.
    func deleteCard(_ card: SavedCard) async -> String? {
        if let token {
            do {
                try await TapcardAPI.deleteCard(token: token, id: card.id)
            } catch APIError.server(let message)
                        where message.localizedCaseInsensitiveContains("not found") {
                // Never synced — nothing to delete remotely.
            } catch {
                return error.localizedDescription
            }
        }
        cards.removeAll { $0.id == card.id }
        persist()
        return nil
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
            createdAt: Date(),
            details: card
        )
        cards.insert(saved, at: 0)
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(cards) {
            UserDefaults.standard.set(data, forKey: cardsKey)
        }
    }

    /// Permanently delete the account on the backend, then sign out locally.
    /// Required by App Store Guideline 5.1.1(v): the backend deactivates +
    /// anonymizes the account so the user can no longer sign in.
    func deleteAccount() async throws {
        guard let email else { return }
        if let token {
            try await TapcardAPI.deleteAccount(token: token, email: email)
        } else {
            let password = KeychainStore.get("password")
            try await TapcardAPI.deleteAccount(email: email, password: password)
        }
        signOut()
    }

    /// Clear all locally-held account state: the email, the saved cards, and the
    /// Keychain credentials. Returns the app to its "no account yet" state.
    func signOut() {
        email = nil
        token = nil
        userName = nil
        cards = []
        UserDefaults.standard.removeObject(forKey: emailKey)
        UserDefaults.standard.removeObject(forKey: cardsKey)
        UserDefaults.standard.removeObject(forKey: "tapcard.userName")
        KeychainStore.delete("email")
        KeychainStore.delete("password")
        KeychainStore.delete("token")
    }
}
