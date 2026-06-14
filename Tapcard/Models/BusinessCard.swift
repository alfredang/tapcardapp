import Foundation

/// Visual theme for the digital card — mirrors the backend `Theme` enum.
enum CardTheme: String, CaseIterable, Identifiable, Codable {
    case corporate = "CORPORATE"
    case modern = "MODERN"
    case minimalist = "MINIMALIST"
    case dark = "DARK"
    case creative = "CREATIVE"
    case luxury = "LUXURY"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .corporate: "Corporate"
        case .modern: "Modern"
        case .minimalist: "Minimalist"
        case .dark: "Dark"
        case .creative: "Creative"
        case .luxury: "Luxury"
        }
    }
}

/// The contact details extracted from a scanned business card and edited by the
/// user before publishing. Field names line up 1:1 with the backend card model
/// so this struct encodes straight into the onboarding request body.
struct BusinessCard: Codable, Equatable {
    var fullName: String = ""
    var jobTitle: String = ""
    var company: String = ""
    var email: String = ""
    var mobile: String = ""
    var officePhone: String = ""
    var website: String = ""
    var address: String = ""

    var linkedin: String = ""
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
