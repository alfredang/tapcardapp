import Foundation

/// Visual theme for the digital card — mirrors the backend `Theme` enum
/// (20 templates; keep in sync with the web's `src/lib/themes.ts`).
enum CardTheme: String, CaseIterable, Identifiable, Codable {
    case corporate = "CORPORATE"
    case modern = "MODERN"
    case minimalist = "MINIMALIST"
    case dark = "DARK"
    case creative = "CREATIVE"
    case luxury = "LUXURY"
    case ocean = "OCEAN"
    case forest = "FOREST"
    case sunset = "SUNSET"
    case rose = "ROSE"
    case indigo = "INDIGO"
    case teal = "TEAL"
    case amber = "AMBER"
    case crimson = "CRIMSON"
    case lavender = "LAVENDER"
    case midnight = "MIDNIGHT"
    case sky = "SKY"
    case mint = "MINT"
    case peach = "PEACH"
    case graphite = "GRAPHITE"

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    /// The theme's banner-gradient endpoint colours (hex), matching the web
    /// tokens — drives the swatches in the theme picker.
    var gradientHexes: (start: String, end: String) {
        switch self {
        case .corporate: ("#1e3a8a", "#2563eb")
        case .modern: ("#6a47f5", "#f86e59")
        case .minimalist: ("#f4f4f5", "#e7e7ea")
        case .dark: ("#18181b", "#2a2a35")
        case .creative: ("#fb7185", "#f59e0b")
        case .luxury: ("#c9a227", "#f0d27a")
        case .ocean: ("#0891b2", "#2563eb")
        case .forest: ("#166534", "#22c55e")
        case .sunset: ("#f97316", "#ec4899")
        case .rose: ("#e11d48", "#fb7185")
        case .indigo: ("#4338ca", "#818cf8")
        case .teal: ("#0d9488", "#2dd4bf")
        case .amber: ("#d97706", "#fbbf24")
        case .crimson: ("#b91c1c", "#ef4444")
        case .lavender: ("#a78bfa", "#f0abfc")
        case .midnight: ("#1e293b", "#0ea5e9")
        case .sky: ("#0284c7", "#38bdf8")
        case .mint: ("#10b981", "#6ee7b7")
        case .peach: ("#fb923c", "#fda4af")
        case .graphite: ("#27272a", "#52525b")
        }
    }
}

/// The contact details extracted from a scanned business card and edited by the
/// user before publishing. Field names line up 1:1 with the backend card model
/// so this struct encodes straight into the onboarding request body.
struct BusinessCard: Codable, Equatable, Hashable {
    var fullName: String = ""
    var jobTitle: String = ""
    /// Short motto shown in italics under the job title.
    var tagline: String = ""
    var company: String = ""
    var email: String = ""
    var mobile: String = ""
    var officePhone: String = ""
    var whatsapp: String = ""
    var website: String = ""
    /// The single address string the backend stores; composed from the
    /// structured parts below when they're filled in.
    var address: String = ""
    /// Short bio shown under the identity block (max 1000 characters).
    var bio: String = ""

    // Structured address entry (app-side; joined into `address` on the wire).
    var addressLine1: String = ""
    var addressLine2: String = ""
    var zipcode: String = ""

    /// Profile photo / cover banner — an https URL or a base64 `data:` URL
    /// (uploaded or AI-generated image), same contract as the web builder.
    var profilePhoto: String = ""
    var coverBanner: String = ""

    var linkedin: String = ""
    var facebook: String = ""
    var instagram: String = ""
    // Kept for older saved cards; no longer editable in the form.
    var twitter: String = ""

    var theme: CardTheme = .modern
    var accentColor: String = Constants.accentHex

    /// Required-field validity for enabling the "Create card" action.
    var isValid: Bool {
        !fullName.trimmed.isEmpty && email.trimmed.isValidEmail
    }

    /// The address as published: structured parts when present, else the raw
    /// scanned string.
    var composedAddress: String {
        let parts = [addressLine1, addressLine2, zipcode].map(\.trimmed).filter { !$0.isEmpty }
        return parts.isEmpty ? address.trimmed : parts.joined(separator: ", ")
    }

    /// Split a flat scanned/synced address into the structured fields (best
    /// effort): a trailing chunk with 4+ digits becomes the postal code. The
    /// flat string is cleared afterwards so the structured fields are the
    /// single source of truth — emptying them really empties the address.
    mutating func decomposeAddressIfNeeded() {
        guard addressLine1.trimmed.isEmpty, addressLine2.trimmed.isEmpty,
              zipcode.trimmed.isEmpty, !address.trimmed.isEmpty else { return }
        var parts = address.components(separatedBy: ",").map(\.trimmed).filter { !$0.isEmpty }
        if let last = parts.last, last.filter(\.isNumber).count >= 4 {
            zipcode = last
            parts.removeLast()
        }
        if !parts.isEmpty { addressLine1 = parts.removeFirst() }
        addressLine2 = parts.joined(separator: ", ")
        address = ""
    }

    // Decode tolerantly: every key optional so cards persisted by any older
    // build (or leaner server payloads) keep loading as fields are added.
    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func str(_ key: CodingKeys) -> String { (try? c.decode(String.self, forKey: key)) ?? "" }
        fullName = str(.fullName)
        jobTitle = str(.jobTitle)
        tagline = str(.tagline)
        company = str(.company)
        email = str(.email)
        mobile = str(.mobile)
        officePhone = str(.officePhone)
        whatsapp = str(.whatsapp)
        website = str(.website)
        address = str(.address)
        bio = str(.bio)
        addressLine1 = str(.addressLine1)
        addressLine2 = str(.addressLine2)
        zipcode = str(.zipcode)
        profilePhoto = str(.profilePhoto)
        coverBanner = str(.coverBanner)
        linkedin = str(.linkedin)
        facebook = str(.facebook)
        instagram = str(.instagram)
        twitter = str(.twitter)
        theme = (try? c.decode(CardTheme.self, forKey: .theme)) ?? .modern
        accentColor = (try? c.decode(String.self, forKey: .accentColor)) ?? Constants.accentHex
    }
}

/// A published card returned by the backend after onboarding.
struct PublishedCard: Codable, Equatable {
    let id: String
    let slug: String
    let url: String
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    var isValidEmail: Bool {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
