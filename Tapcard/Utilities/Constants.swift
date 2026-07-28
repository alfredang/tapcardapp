import Foundation

/// App-wide constants. The backend base URL points at the Tapcard web app /
/// API deployed on Coolify; everything the app persists lands in that same
/// Postgres database.
enum Constants {
    /// Production Tapcard backend (Next.js on Coolify).
    static let apiBaseURL = URL(string: "https://tapcard.tertiaryinfotech.com")!

    /// Onboarding endpoint: account-setup + digital-card creation in one call.
    static let onboardPath = "/api/mobile/onboard"

    /// Account-deletion endpoint: deactivates + anonymizes the account so the
    /// user can no longer sign in (App Store Guideline 5.1.1(v)).
    static let deleteAccountPath = "/api/mobile/delete-account"

    /// Optional shared key sent as `x-tapcard-key`. Leave empty unless the
    /// backend sets `MOBILE_API_KEY`; the header is omitted when blank.
    static let mobileKey = ""

    /// Brand palette, matching tapcard.tertiaryinfotech.com: a violet primary
    /// with a coral and a teal secondary used for gradients and highlights.
    /// Kept in sync with `Theme` (the full design system port).
    static let accentHex = "#6A47F5"     // --primary  hsl(252 90% 62%)
    static let accentDeepHex = "#5B3FE0"
    static let coralHex = "#F86E59"      // --accent   hsl(8 92% 66%)
    static let tealHex = "#16B6A0"       // --highlight hsl(172 78% 40%)

    static let supportURL = URL(string: "https://www.tertiaryinfotech.com")!
}
