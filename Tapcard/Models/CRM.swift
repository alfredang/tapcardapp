import Foundation

/// A person you've saved — the iOS twin of the web app's `Contact` model.
/// Populated by hand, by saving a captured `Lead`, or from a scanned QR code.
/// Synced to the shared backend so it also appears in the web CRM.
struct Contact: Codable, Identifiable, Equatable, Sendable {
    var id: String = ""
    var name: String = ""
    var company: String = ""
    var position: String = ""
    var email: String = ""
    var phone: String = ""
    var whatsapp: String = ""
    var address: String = ""
    var notes: String = ""
    var tags: String = ""

    var displayName: String {
        !name.isEmpty ? name : (!company.isEmpty ? company : (!email.isEmpty ? email : "Unnamed contact"))
    }

    /// Secondary line: "Position · Company" with whichever parts exist.
    var subtitle: String {
        [position, company].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// A lead captured from one of your public web cards — someone filled in the
/// "share your details" form. Read-only: save it as a `Contact` or dismiss it.
struct Lead: Codable, Identifiable, Equatable, Sendable {
    var id: String = ""
    var name: String = ""
    var email: String = ""
    var phone: String = ""
    var company: String = ""
    var message: String = ""
    var source: String = "card"
    var createdAt: String = ""

    var displayName: String {
        !name.isEmpty ? name : (!email.isEmpty ? email : "New lead")
    }

    func toContact() -> Contact {
        Contact(name: name, company: company, email: email, phone: phone, notes: message)
    }
}

/// A to-do — the iOS twin of the web CRM's Task model, synced to the backend.
/// Named `CRMTask` to avoid clashing with Swift Concurrency's `Task`.
struct CRMTask: Codable, Identifiable, Equatable, Sendable {
    var id: String = ""
    var title: String = ""
    var type: String = "FOLLOW_UP"  // FOLLOW_UP | REMINDER | MEETING
    var status: String = "TODO"     // TODO | IN_PROGRESS | DONE
    var dueAt: String?
    var contactId: String?
    var createdAt: String = ""

    var isDone: Bool { status == "DONE" }

    static let types = ["FOLLOW_UP", "REMINDER", "MEETING"]

    /// "FOLLOW_UP" -> "Follow up".
    static func typeLabel(_ type: String) -> String {
        type.split(separator: "_")
            .map { $0.lowercased() }
            .joined(separator: " ")
            .capitalizedFirst
    }
}

/// A calendar appointment / booking — the iOS twin of the web CRM's model.
struct Appointment: Codable, Identifiable, Equatable, Sendable {
    var id: String = ""
    var name: String = ""
    var email: String?
    var startAt: String = ""  // ISO-8601 instant
    var endAt: String = ""    // ISO-8601 instant
    var status: String = "REQUESTED"  // REQUESTED | CONFIRMED | CANCELLED | COMPLETED
    var notes: String?
    var createdAt: String = ""

    static func statusLabel(_ status: String) -> String { status.lowercased().capitalizedFirst }
}

/// Headline counts across all of the user's cards.
struct AnalyticsTotals: Codable, Equatable, Sendable {
    var views: Int = 0
    var taps: Int = 0
    var leads: Int = 0
}

/// Per-card performance row.
struct CardStats: Codable, Identifiable, Equatable, Sendable {
    var id: String = ""
    var name: String = ""
    var slug: String = ""
    var views: Int = 0
    var taps: Int = 0
}

/// Card-performance summary — mirrors GET /api/mobile/analytics. `byType`
/// maps raw event names (VIEW, QR_SCAN, EMAIL_CLICK, …) to counts.
struct AnalyticsSummary: Codable, Equatable, Sendable {
    var totals: AnalyticsTotals = AnalyticsTotals()
    var byType: [String: Int] = [:]
    var last30dViews: Int = 0
    var cards: [CardStats] = []
}

extension String {
    var capitalizedFirst: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }
}

/// ISO-8601 helpers for the planner's `dueAt` / `startAt` / `endAt` instants.
enum ISO8601 {
    static func date(from string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }

    static func string(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
