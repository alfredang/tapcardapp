import SwiftUI

/// International phone formatting for WhatsApp, tel: links and vCards.
///
/// wa.me needs the full international number — "96983731" on its own makes
/// WhatsApp answer "couldn't look up phone number … missing a country code".
/// People type local numbers on their cards, so every outbound number goes
/// through `internationalDigits` with the account's default country code
/// (Settings → Sharing → Country).
///
/// Keep in sync with the backend's `internationalDigits` (src/lib/whatsapp.ts).
enum PhoneNumber {

    static let defaultCountryCode = "65"

    /// National significant-number lengths for the common dialling codes —
    /// tells "6588666375" (an SG number already carrying 65) apart from
    /// "9123456789" (an Indian local number that merely starts with 91).
    private static let nationalLengths: [String: ClosedRange<Int>] = [
        "1": 10...10, "44": 9...10, "60": 8...10, "61": 9...9, "62": 8...12,
        "63": 10...10, "65": 8...8, "66": 8...9, "81": 9...10, "82": 8...10,
        "84": 9...10, "86": 11...11, "91": 10...10, "852": 8...8, "853": 8...8,
        "886": 9...9, "971": 8...9,
    ]

    /// Digits-only international form: "9698 3731" → "6596983731",
    /// "+60 12-345 6789" → "60123456789", "012-345 6789" (cc 60) → "60123456789".
    static func internationalDigits(_ raw: String, countryCode: String = defaultCountryCode) -> String {
        let input = raw.trimmed
        let digits = input.filter(\.isASCIIDigit)
        guard !digits.isEmpty else { return "" }
        if input.hasPrefix("+") { return digits }
        if digits.hasPrefix("00") { return String(digits.dropFirst(2)) }
        var cc = countryCode.filter(\.isASCIIDigit)
        if cc.isEmpty { cc = defaultCountryCode }
        if digits.hasPrefix("0") { return cc + digits.drop(while: { $0 == "0" }) }
        let range = nationalLengths[cc] ?? 7...12
        if digits.hasPrefix(cc), range.contains(digits.count - cc.count), !range.contains(digits.count) {
            return digits
        }
        return cc + digits
    }

    /// Readable international form of digits from `internationalDigits`:
    /// "6596983731" → "+65 9698 3731". Groups of four after the country code
    /// when it's the account's own; otherwise just "+digits".
    static func display(digits: String, countryCode: String) -> String {
        guard digits.hasPrefix(countryCode), digits.count > countryCode.count else { return "+" + digits }
        let national = Array(digits.dropFirst(countryCode.count))
        var groups: [String] = []
        var index = national.count % 4 == 0 ? 0 : national.count % 4
        if index > 0 { groups.append(String(national[0..<index])) }
        while index < national.count {
            groups.append(String(national[index..<min(index + 4, national.count)]))
            index += 4
        }
        return "+\(countryCode) " + groups.joined(separator: " ")
    }

    /// "+6596983731", or "" when there's no number.
    static func international(_ raw: String, countryCode: String = defaultCountryCode) -> String {
        let digits = internationalDigits(raw, countryCode: countryCode)
        return digits.isEmpty ? "" : "+" + digits
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}

/// A selectable default country. Same list as the web's src/lib/countries.ts.
struct DialCountry: Identifiable, Hashable {
    let code: String
    let name: String
    let flag: String
    var id: String { code }
    var label: String { "\(flag) \(name)" }

    static let all: [DialCountry] = [
        .init(code: "65", name: "Singapore", flag: "🇸🇬"),
        .init(code: "60", name: "Malaysia", flag: "🇲🇾"),
        .init(code: "62", name: "Indonesia", flag: "🇮🇩"),
        .init(code: "66", name: "Thailand", flag: "🇹🇭"),
        .init(code: "63", name: "Philippines", flag: "🇵🇭"),
        .init(code: "84", name: "Vietnam", flag: "🇻🇳"),
        .init(code: "852", name: "Hong Kong", flag: "🇭🇰"),
        .init(code: "86", name: "China", flag: "🇨🇳"),
        .init(code: "886", name: "Taiwan", flag: "🇹🇼"),
        .init(code: "81", name: "Japan", flag: "🇯🇵"),
        .init(code: "82", name: "South Korea", flag: "🇰🇷"),
        .init(code: "91", name: "India", flag: "🇮🇳"),
        .init(code: "971", name: "United Arab Emirates", flag: "🇦🇪"),
        .init(code: "61", name: "Australia", flag: "🇦🇺"),
        .init(code: "44", name: "United Kingdom", flag: "🇬🇧"),
        .init(code: "1", name: "United States / Canada", flag: "🇺🇸"),
    ]

    static func named(_ code: String) -> DialCountry {
        all.first { $0.code == code } ?? .init(code: code, name: "+\(code)", flag: "🌐")
    }
}

extension EnvironmentValues {
    /// The account's default dialling code (Settings → Sharing), set at the
    /// root so every card view builds working WhatsApp / tel: links.
    @Entry var dialCountryCode: String = PhoneNumber.defaultCountryCode
}
