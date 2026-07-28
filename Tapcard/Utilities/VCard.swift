import Foundation

/// Builds a .vcf file for a card so a shared contact can be added straight to
/// the recipient's phone Contacts — and from there used in WhatsApp, calls or
/// SMS. Mirrors the backend's /api/c/[slug]/vcf output.
enum VCard {

    /// Write the card as a temporary .vcf and return its file URL.
    static func file(for card: BusinessCard, publicURL: String?) -> URL? {
        let name = card.fullName.trimmed
        guard !name.isEmpty else { return nil }

        var lines = ["BEGIN:VCARD", "VERSION:3.0"]
        lines.append("FN:\(escape(name))")
        // Last-name-first N field: best effort from the display name.
        let parts = name.split(separator: " ").map(String.init)
        let family = parts.count > 1 ? parts.last! : ""
        let given = parts.count > 1 ? parts.dropLast().joined(separator: " ") : name
        lines.append("N:\(escape(family));\(escape(given));;;")

        if !card.jobTitle.trimmed.isEmpty { lines.append("TITLE:\(escape(card.jobTitle.trimmed))") }
        if !card.company.trimmed.isEmpty { lines.append("ORG:\(escape(card.company.trimmed))") }
        if !card.mobile.trimmed.isEmpty { lines.append("TEL;TYPE=CELL:\(escape(card.mobile.trimmed))") }
        if !card.officePhone.trimmed.isEmpty { lines.append("TEL;TYPE=WORK:\(escape(card.officePhone.trimmed))") }
        if !card.email.trimmed.isEmpty { lines.append("EMAIL;TYPE=WORK:\(escape(card.email.trimmed))") }
        if !card.website.trimmed.isEmpty { lines.append("URL:\(escape(card.website.trimmed))") }
        if !card.composedAddress.isEmpty {
            lines.append("ADR;TYPE=WORK:;;\(escape(card.composedAddress));;;;")
        }
        if !card.bio.trimmed.isEmpty {
            lines.append("NOTE:\(escape(String(card.bio.trimmed.prefix(500))))")
        }
        if let publicURL, !publicURL.isEmpty {
            lines.append("URL;TYPE=Tapcard:\(escape(publicURL))")
        }
        lines.append("END:VCARD")

        let text = lines.joined(separator: "\r\n") + "\r\n"
        let safeName = name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName).vcf")
        do {
            try text.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ";", with: "\\;")
    }
}
