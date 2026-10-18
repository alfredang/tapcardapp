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

    /// Synced account preferences (Settings → Sharing). Cached so the QR and
    /// phone links are right offline; refreshed from the server on launch.
    private(set) var preferences = UserPreferences()
    private let preferencesKey = "tapcard.preferences"
    private let preferencesDirtyKey = "tapcard.preferencesDirty"
    private(set) var biometricEnabled = false
    private(set) var isUnlocking = false
    var needsBiometricUnlock: Bool { biometricEnabled && token == nil }

    func setBiometricEnabled(_ enabled: Bool) async throws {
        let context = try await BiometricAuthService.authenticate()
        if enabled {
            guard let token else { return }
            try KeychainStore.setBiometricToken(token)
            KeychainStore.delete("token")
            biometricEnabled = true
        } else {
            let restored = try KeychainStore.biometricToken(context: context)
            KeychainStore.set(restored, for: "token")
            KeychainStore.delete("biometricToken")
            biometricEnabled = false
        }
    }

    func lockSession() {
        guard biometricEnabled, !isUnlocking else { return }
        cardsGeneration += 1
        token = nil
    }

    func unlockSession() async throws {
        guard !isUnlocking else { return }
        isUnlocking = true
        defer { isUnlocking = false }
        let context = try await BiometricAuthService.authenticate()
        token = try KeychainStore.biometricToken(context: context)
        await refreshServerCards()
        await refreshPreferences()
    }

    private let cardsKey = "tapcard.savedCards"
    private let emailKey = "tapcard.email"

    init() {
        if DemoSupport.seedCards {
            email = "jordan@lumen.studio"
            token = "demo-token"
            userName = "Jordan Avery"
            cards = DemoSupport.demoSavedCards
            if let link = DemoSupport.whatsappQr { preferences.whatsappQr = link }
            return
        }
        email = UserDefaults.standard.string(forKey: emailKey)
        biometricEnabled = KeychainStore.hasBiometricToken
        token = biometricEnabled ? nil : KeychainStore.get("token")
        userName = UserDefaults.standard.string(forKey: "tapcard.userName")
        if let data = UserDefaults.standard.data(forKey: preferencesKey),
           let saved = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            preferences = saved
        }
        if let data = UserDefaults.standard.data(forKey: cardsKey),
           let decoded = try? JSONDecoder().decode([SavedCard].self, from: data) {
            cards = decoded.sorted { $0.createdAt > $1.createdAt }
        }
    }

    /// Store a successful login / register / OTP-verify session.
    func startSession(_ result: AuthResult) {
        cardsGeneration += 1
        KeychainStore.delete("biometricToken")
        biometricEnabled = false
        token = result.token
        userName = result.name
        email = result.email ?? email
        KeychainStore.set(result.token, for: "token")
        if let email { UserDefaults.standard.set(email, forKey: emailKey) }
        if let name = result.name { UserDefaults.standard.set(name, forKey: "tapcard.userName") }
        Task {
            await refreshServerCards()
            await refreshPreferences()
        }
    }

    // ─── Preferences (synced with the web's /settings) ──────────────────────

    /// Pull the account's preferences. A change made offline is pushed first,
    /// so it isn't overwritten by the server's older copy.
    func refreshPreferences() async {
        guard let token, !DemoSupport.seedCards else { return }
        if UserDefaults.standard.bool(forKey: preferencesDirtyKey) {
            let local: [String: Any] = ["countryCode": preferences.countryCode,
                                        "qrMode": preferences.qrMode.rawValue,
                                        "whatsappQr": preferences.whatsappQr]
            guard (try? await TapcardAPI.updateSettings(token: token, local)) != nil else { return }
            UserDefaults.standard.set(false, forKey: preferencesDirtyKey)
        }
        guard let server = try? await TapcardAPI.fetchSettings(token: token), self.token == token else { return }
        preferences = server
        persistPreferences()
    }

    /// Apply a preference change immediately (it works offline — the QR
    /// switch at an event can't wait on signal), then sync it to the account.
    /// Returns an error message when the sync failed; it's retried on the
    /// next refresh.
    func updatePreferences(countryCode: String? = nil, qrMode: QRMode? = nil,
                           whatsappQr: String? = nil) async -> String? {
        var changes: [String: Any] = [:]
        if let countryCode { preferences.countryCode = countryCode; changes["countryCode"] = countryCode }
        if let qrMode { preferences.qrMode = qrMode; changes["qrMode"] = qrMode.rawValue }
        if let whatsappQr { preferences.whatsappQr = whatsappQr; changes["whatsappQr"] = whatsappQr }
        persistPreferences()
        guard let token, !changes.isEmpty, !DemoSupport.seedCards else { return nil }
        do {
            let saved = try await TapcardAPI.updateSettings(token: token, changes)
            UserDefaults.standard.set(false, forKey: preferencesDirtyKey)
            preferences = saved
            persistPreferences()
            return nil
        } catch {
            UserDefaults.standard.set(true, forKey: preferencesDirtyKey)
            return "Saved on this device; it will sync to your account when you're back online. (\(error.localizedDescription))"
        }
    }

    private func persistPreferences() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: preferencesKey)
        }
    }

    // ─── Card edits from outside the editor ────────────────────────────────

    /// Cards re-published to this account get a new server id; views opened
    /// with the old id follow it through here.
    private var movedCardIDs: [String: String] = [:]

    func card(withID id: String) -> SavedCard? {
        let id = movedCardIDs[id] ?? id
        return cards.first { $0.id == id }
    }

    /// Change a card's design and accent — live in the app at once, then
    /// saved to the server so the web card matches. Returns an error message
    /// (and reverts) on failure.
    func updateDesign(of cardID: String, theme: CardTheme, accentColor: String) async -> String? {
        let cardID = movedCardIDs[cardID] ?? cardID
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return nil }
        let previous = cards[index].details
        var details = previous ?? BusinessCard()
        details.theme = theme
        details.accentColor = accentColor
        cardsGeneration += 1
        cards[index].details = details
        persist()
        guard let token, !DemoSupport.seedCards else { return nil }
        do {
            try await TapcardAPI.updateCardDesign(token: token, id: cardID, theme: theme, accentColor: accentColor)
            return nil
        } catch APIError.server(let message) where message.localizedCaseInsensitiveContains("not found") {
            do {
                try await adopt(cardID, details: details, token: token)
                return nil
            } catch {
                if let i = cards.firstIndex(where: { $0.id == cardID }) { cards[i].details = previous }
                persist()
                return error.localizedDescription
            }
        } catch {
            if let i = cards.firstIndex(where: { $0.id == cardID }) { cards[i].details = previous }
            persist()
            return error.localizedDescription
        }
    }

    /// Save a full card (e.g. a LinkedIn profile added from the QR panel).
    func saveCard(_ cardID: String, details: BusinessCard) async -> String? {
        guard let token else { return "You're signed out. Sign in again to edit." }
        let cardID = movedCardIDs[cardID] ?? cardID
        do {
            do {
                try await TapcardAPI.updateCard(token: token, id: cardID, card: details)
                if let i = cards.firstIndex(where: { $0.id == cardID }) {
                    cardsGeneration += 1
                    cards[i].details = details
                    persist()
                }
            } catch APIError.server(let message) where message.localizedCaseInsensitiveContains("not found") {
                try await adopt(cardID, details: details, token: token)
            }
            await refreshServerCards()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// A card published under a different account — e.g. scanned with a
    /// work email before signing in with Apple — can't be edited by this
    /// session (the server answers "Not found"), which made every design
    /// tap snap back. Publish it to the signed-in account and swap the local
    /// copy for that one, keeping its place in the list.
    private func adopt(_ cardID: String, details: BusinessCard, token: String) async throws {
        let response = try await TapcardAPI.onboard(details, token: token)
        movedCardIDs[cardID] = response.card.id
        guard let i = cards.firstIndex(where: { $0.id == cardID }) else { return }
        cardsGeneration += 1
        cards[i].id = response.card.id
        cards[i].slug = response.card.slug
        cards[i].url = response.card.url
        cards[i].details = details
        persist()
    }

    /// Bumped by every local mutation (delete/publish); a refresh whose fetch
    /// started before the mutation is stale and must not overwrite the list —
    /// otherwise a deleted card "comes back" when the old response lands.
    private var cardsGeneration = 0

    /// Pull the account's published cards from the backend so Home lists them
    /// on any device, not just the one that created them.
    func refreshServerCards() async {
        guard let token else { return }
        cardsGeneration += 1
        let generation = cardsGeneration
        guard let server = try? await TapcardAPI.fetchCards(token: token) else { return }
        guard generation == cardsGeneration, self.token == token else { return } // superseded mid-flight
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
        cardsGeneration += 1   // invalidate any in-flight refresh
        cards.removeAll { $0.id == card.id }
        persist()
        // Converge with the server's post-delete state.
        Task { await refreshServerCards() }
        return nil
    }

    func record(_ response: OnboardResponse, card: BusinessCard) {
        cardsGeneration += 1   // invalidate any in-flight refresh
        // Signed in, the card joined this account — the email on the card
        // isn't the account's, so keep the session's identity.
        if token == nil {
            email = response.email
            UserDefaults.standard.set(response.email, forKey: emailKey)
            KeychainStore.set(response.email, for: "email")
            if let pw = response.password {
                KeychainStore.set(pw, for: "password")
            }
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
        cardsGeneration += 1
        biometricEnabled = false
        KeychainStore.delete("biometricToken")
        email = nil
        token = nil
        userName = nil
        cards = []
        preferences = UserPreferences()
        UserDefaults.standard.removeObject(forKey: preferencesKey)
        UserDefaults.standard.removeObject(forKey: preferencesDirtyKey)
        UserDefaults.standard.removeObject(forKey: emailKey)
        UserDefaults.standard.removeObject(forKey: cardsKey)
        UserDefaults.standard.removeObject(forKey: "tapcard.userName")
        KeychainStore.delete("email")
        KeychainStore.delete("password")
        KeychainStore.delete("token")
    }
}
