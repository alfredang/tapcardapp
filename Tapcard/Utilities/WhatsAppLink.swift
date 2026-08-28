import Foundation

/// Phone- and profile-link helpers for a card's QR code and vCard.
///
/// The QR itself points at the card page (`?wa=1`), which performs the
/// WhatsApp hand-off — see `CardQRTarget`. What lives here is the shared
/// question of *whether* a card can be reached on WhatsApp at all, plus the
/// LinkedIn URL normalisation used by the vCard and the photo importer.
enum WhatsAppLink {

    /// The number the card should be reached on: the explicit WhatsApp field,
    /// falling back to mobile, then landline. Nil when the card carries no
    /// usable number — the QR then just opens the card.
    static func number(for card: BusinessCard) -> String? {
        for candidate in [card.whatsapp, card.mobile, card.officePhone] {
            let digits = normalize(candidate)
            if digits.count >= 8 { return digits }
        }
        return nil
    }

    /// The card's LinkedIn profile as a full https URL, or nil when unset.
    /// Accepts what people actually type: a bare handle, `linkedin.com/in/…`,
    /// or a complete URL.
    static func linkedInURL(for card: BusinessCard) -> String? {
        let raw = card.linkedin.trimmed
        guard !raw.isEmpty else { return nil }
        if raw.lowercased().hasPrefix("http") { return raw }
        if raw.lowercased().contains("linkedin.com") { return "https://" + raw }
        // A bare handle — "jordanavery" or "in/jordanavery".
        let handle = raw.hasPrefix("in/") ? String(raw.dropFirst(3)) : raw
        return "https://www.linkedin.com/in/\(handle)"
    }

    /// Strip everything but digits, dropping a leading `+` and any `00`
    /// international prefix — wa.me wants the bare country-code + number.
    private static func normalize(_ raw: String) -> String {
        var digits = raw.filter(\.isNumber)
        if digits.hasPrefix("00") { digits.removeFirst(2) }
        return digits
    }
}
