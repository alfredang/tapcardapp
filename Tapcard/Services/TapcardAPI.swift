import Foundation

/// Result of a successful onboarding call.
struct OnboardResponse: Codable {
    let ok: Bool
    let isNewAccount: Bool
    let email: String
    let password: String?
    let card: PublishedCard
}

enum APIError: LocalizedError {
    case server(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .server(let message): message
        case .invalidResponse: "The server returned an unexpected response."
        }
    }
}

/// Thin client for the Tapcard backend deployed on Coolify.
enum TapcardAPI {
    /// POST the scanned + edited card to `/api/mobile/onboard`. The backend
    /// finds-or-creates the account and publishes the digital card, persisting
    /// everything to the Coolify Postgres. Returns the public card URL.
    static func onboard(_ card: BusinessCard) async throws -> OnboardResponse {
        let url = Constants.apiBaseURL.appendingPathComponent(Constants.onboardPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !Constants.mobileKey.isEmpty {
            request.setValue(Constants.mobileKey, forHTTPHeaderField: "x-tapcard-key")
        }
        request.httpBody = try JSONEncoder().encode(OnboardRequest(card))
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        if !(200...299).contains(http.statusCode) {
            if let err = try? JSONDecoder().decode(ServerError.self, from: data) {
                throw APIError.server(err.error)
            }
            throw APIError.server("Request failed (HTTP \(http.statusCode)).")
        }

        do {
            return try JSONDecoder().decode(OnboardResponse.self, from: data)
        } catch {
            throw APIError.invalidResponse
        }
    }

    /// DELETE the account behind `email` via `/api/mobile/delete-account`. The
    /// backend deactivates + anonymizes the account (App Store Guideline
    /// 5.1.1(v)). `password` is sent when the app holds it (Keychain) so the
    /// backend can verify ownership; it is optional because returning accounts
    /// are not issued a password on this device.
    static func deleteAccount(email: String, password: String?) async throws {
        let url = Constants.apiBaseURL.appendingPathComponent(Constants.deleteAccountPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !Constants.mobileKey.isEmpty {
            request.setValue(Constants.mobileKey, forHTTPHeaderField: "x-tapcard-key")
        }
        request.httpBody = try JSONEncoder().encode(DeleteAccountRequest(email: email, password: password))
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        if !(200...299).contains(http.statusCode) {
            if let err = try? JSONDecoder().decode(ServerError.self, from: data) {
                throw APIError.server(err.error)
            }
            throw APIError.server("Request failed (HTTP \(http.statusCode)).")
        }
    }

    private struct ServerError: Codable { let error: String }
}

/// Wire format for the account-deletion request. `password` is omitted from the
/// JSON when nil so the backend treats it as "not provided".
private struct DeleteAccountRequest: Encodable {
    let email: String
    let password: String?
}

/// Wire format for the onboarding request — non-empty fields only, so the
/// backend's optional-URL/email validators don't reject blank strings.
private struct OnboardRequest: Encodable {
    let fullName: String
    let email: String
    let jobTitle: String?
    let company: String?
    let mobile: String?
    let officePhone: String?
    let website: String?
    let address: String?
    let linkedin: String?
    let twitter: String?
    let theme: String
    let accentColor: String

    init(_ card: BusinessCard) {
        func opt(_ s: String) -> String? {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        fullName = card.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        email = card.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        jobTitle = opt(card.jobTitle)
        company = opt(card.company)
        mobile = opt(card.mobile)
        officePhone = opt(card.officePhone)
        website = opt(card.website)
        address = opt(card.address)
        linkedin = opt(card.linkedin)
        twitter = opt(card.twitter)
        theme = card.theme.rawValue
        accentColor = card.accentColor
    }
}
