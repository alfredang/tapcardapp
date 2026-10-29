import Foundation

/// Phone- and profile-link helpers for a card's QR code and vCard.
///
/// The QR itself is a `wa.me` link — see `CardQRTarget`. What lives here is the shared
/// question of *whether* a card can be reached on WhatsApp at all, plus the
/// LinkedIn URL normalisation used by the vCard and the photo importer.
enum WhatsAppLink {

    /// The number the card should be reached on, as international digits
    /// ("6596983731"): the explicit WhatsApp field, falling back to mobile,
    /// then landline. Nil when the card carries no usable number — the QR
    /// then just opens the card. Same order as the backend's whatsappNumber.
    static func number(for card: BusinessCard,
                       countryCode: String = PhoneNumber.defaultCountryCode) -> String? {
        for candidate in [card.whatsapp, card.mobile, card.officePhone]
        where candidate.filter(\.isNumber).count >= 6 {
            return PhoneNumber.internationalDigits(candidate, countryCode: countryCode)
        }
        return nil
    }

    /// Pull your WhatsApp contact link out of pasted text or a scanned QR
    /// payload — WhatsApp's share text wraps it in a sentence — as
    /// "https://wa.me/qr/<code>". Nil when there's none. Same rule as the
    /// backend's whatsappQrLink.
    static func contactLink(in text: String) -> String? {
        guard let match = text.firstMatch(of: /(?i)(?:wa\.me|api\.whatsapp\.com)\/qr\/([A-Za-z0-9]+)/)
        else { return nil }
        return "https://wa.me/qr/\(match.1)"
    }

    /// "+65 9698 3731"-style display of the number a WhatsApp QR chats with.
    static func displayNumber(for card: BusinessCard, countryCode: String) -> String? {
        number(for: card, countryCode: countryCode).map { "+" + $0 }
    }

    /// The card's LinkedIn profile as a full https URL, or nil when unset.
    /// Accepts what people actually type: a bare handle, `linkedin.com/in/…`,
    /// or a complete URL.
    static func linkedInURL(for card: BusinessCard) -> String? {
        let raw = card.linkedin.trimmed
        guard !raw.isEmpty else { return nil }
        let normalized: String
        if raw.lowercased().hasPrefix("http") { normalized = raw }
        else if raw.lowercased().hasPrefix("linkedin.com/") || raw.lowercased().hasPrefix("www.linkedin.com/") {
            normalized = "https://" + raw
        } else {
            let handle = raw.hasPrefix("in/") ? String(raw.dropFirst(3)) : raw
            guard !handle.contains("/"), !handle.contains(" "), !handle.contains("?") else { return nil }
            normalized = "https://www.linkedin.com/in/\(handle)"
        }
        guard var components = URLComponents(string: normalized),
              let host = components.host?.lowercased(),
              host == "linkedin.com" || host.hasSuffix(".linkedin.com"),
              components.path.hasPrefix("/in/"), components.path.count > 4,
              components.user == nil, components.password == nil else { return nil }
        components.scheme = "https"
        components.query = nil
        components.fragment = nil
        return components.url?.absoluteString
    }
}
