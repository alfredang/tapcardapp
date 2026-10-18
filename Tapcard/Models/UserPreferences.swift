import Foundation

/// What a card's QR code opens. Raw values are the backend's `User.qrMode`.
enum QRMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case whatsapp = "WHATSAPP"
    case linkedin = "LINKEDIN"
    case card = "CARD"

    var id: Self { self }

    var label: String {
        switch self {
        case .whatsapp: "WhatsApp"
        case .linkedin: "LinkedIn"
        case .card: "Card link"
        }
    }

    var icon: String {
        switch self {
        case .whatsapp: "message.fill"
        case .linkedin: "person.badge.plus"
        case .card: "person.text.rectangle"
        }
    }
}

/// Account preferences, edited in Settings and synced to the web's /settings
/// (GET/PATCH /api/mobile/settings). Cached locally so the QR renders right
/// away offline.
struct UserPreferences: Codable, Equatable, Sendable {
    /// Default dialling code, digits only ("65").
    var countryCode: String = PhoneNumber.defaultCountryCode
    /// What the QR on the Cards tab opens by default.
    var qrMode: QRMode = .whatsapp
    /// Your own WhatsApp contact link ("https://wa.me/qr/…"), copied from
    /// WhatsApp → QR code; "" when unset. When set, the WhatsApp QR is the
    /// same as WhatsApp's: scanning adds you as a contact.
    var whatsappQr: String = ""

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        countryCode = (try? c.decode(String.self, forKey: .countryCode))
            .flatMap { $0.isEmpty ? nil : $0 } ?? PhoneNumber.defaultCountryCode
        qrMode = (try? c.decode(QRMode.self, forKey: .qrMode)) ?? .whatsapp
        whatsappQr = (try? c.decode(String.self, forKey: .whatsappQr)) ?? ""
    }
}

extension TapcardAPI {
    private struct SettingsWire: Codable { let settings: UserPreferences? }

    static func fetchSettings(token: String) async throws -> UserPreferences {
        let data = try await authorizedRequest("GET", "/api/mobile/settings", token: token)
        return (try? JSONDecoder().decode(SettingsWire.self, from: data))?.settings ?? UserPreferences()
    }

    /// Send only the changed fields; returns what the server saved.
    static func updateSettings(token: String, _ changes: [String: Any]) async throws -> UserPreferences {
        let data = try await authorizedRequest("PATCH", "/api/mobile/settings", token: token, body: changes)
        guard let saved = try? JSONDecoder().decode(SettingsWire.self, from: data).settings else {
            throw APIError.invalidResponse
        }
        return saved
    }
}
