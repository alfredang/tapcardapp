import Foundation

/// Heuristic parser that turns OCR text lines from a business card into a
/// structured `BusinessCard`. Detection order matters: emails, URLs and phones
/// are unambiguous and get pulled out first; the remaining lines are then
/// ranked to guess the person's name, job title and company.
enum ContactParser {
    private static let emailRegex = #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#
    private static let urlRegex = #"((https?://)?(www\.)?[A-Z0-9-]+\.[A-Z]{2,}(/[^\s]*)?)"#
    // Phone: 7+ digits allowing +, spaces, dashes, parentheses and dots.
    private static let phoneRegex = #"(\+?\d[\d\s().\-]{6,}\d)"#

    private static let titleKeywords = [
        "ceo", "cto", "cfo", "coo", "founder", "co-founder", "president",
        "director", "manager", "engineer", "developer", "designer", "consultant",
        "officer", "head", "lead", "specialist", "analyst", "architect",
        "executive", "owner", "partner", "vp", "vice president", "sales",
        "marketing", "account", "principal", "associate", "coordinator",
    ]
    private static let companyKeywords = [
        "inc", "llc", "ltd", "pte", "corp", "company", "co.", "group",
        "technologies", "technology", "solutions", "systems", "labs", "studio",
        "consulting", "global", "ventures", "partners", "holdings", "academy",
    ]

    static func parse(lines: [String]) -> BusinessCard {
        var card = BusinessCard()
        var remaining: [String] = []

        for line in lines {
            if card.email.isEmpty, let email = firstMatch(emailRegex, in: line) {
                card.email = email.lowercased()
                continue
            }
            if card.website.isEmpty,
               let url = firstMatch(urlRegex, in: line),
               !url.contains("@"),
               url.contains(".") {
                card.website = normalizeURL(url)
                continue
            }
            if let phone = firstMatch(phoneRegex, in: line) {
                let mobileHint = line.lowercased()
                if mobileHint.contains("m") || mobileHint.contains("cell") || mobileHint.contains("mobile") {
                    if card.mobile.isEmpty { card.mobile = phone.cleanedPhone; continue }
                }
                if card.officePhone.isEmpty { card.officePhone = phone.cleanedPhone; continue }
                if card.mobile.isEmpty { card.mobile = phone.cleanedPhone; continue }
                continue
            }
            if line.lowercased().contains("linkedin") {
                card.linkedin = normalizeURL(line); continue
            }
            remaining.append(line)
        }

        // Classify the leftover text lines.
        var nameCandidate: String?
        var titleCandidate: String?
        var companyCandidate: String?
        var addressParts: [String] = []

        for line in remaining {
            let lower = line.lowercased()
            if titleCandidate == nil, titleKeywords.contains(where: { lower.contains($0) }) {
                titleCandidate = line
            } else if companyCandidate == nil, companyKeywords.contains(where: { lower.contains($0) }) {
                companyCandidate = line
            } else if looksLikeAddress(line) {
                addressParts.append(line)
            } else if nameCandidate == nil, looksLikeName(line) {
                nameCandidate = line
            } else {
                addressParts.append(line)
            }
        }

        // Fallback: first leftover line is most often the name.
        card.fullName = nameCandidate ?? remaining.first ?? ""
        card.jobTitle = titleCandidate ?? ""
        card.company = companyCandidate ?? ""
        card.address = addressParts.joined(separator: ", ")
        return card
    }

    // MARK: - Heuristics

    private static func looksLikeName(_ line: String) -> Bool {
        let words = line.split(separator: " ")
        guard (1...4).contains(words.count) else { return false }
        // Mostly alphabetic, capitalized words, no digits.
        guard !line.contains(where: \.isNumber) else { return false }
        let capitalized = words.filter { $0.first?.isUppercase == true }.count
        return capitalized >= max(1, words.count - 1)
    }

    private static func looksLikeAddress(_ line: String) -> Bool {
        let lower = line.lowercased()
        let hints = ["street", "st.", "road", "rd", "ave", "avenue", "suite",
                     "floor", "blvd", "lane", "drive", "#", "singapore"]
        let hasDigits = line.contains(where: \.isNumber)
        return hasDigits && hints.contains(where: { lower.contains($0) })
    }

    private static func normalizeURL(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespaces)
        if let r = s.range(of: urlRegex, options: [.regularExpression, .caseInsensitive]) {
            s = String(s[r])
        }
        if !s.lowercased().hasPrefix("http") { s = "https://" + s }
        return s
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let r = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        return String(text[r])
    }
}

private extension String {
    var cleanedPhone: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
