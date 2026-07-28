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
    var company: String = ""
    var email: String = ""
    var mobile: String = ""
    var officePhone: String = ""
    var website: String = ""
    var address: String = ""

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
