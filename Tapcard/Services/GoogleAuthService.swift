import Foundation
import UIKit
import GoogleSignIn

/// Outcome of the Google account picker — the iOS twin of the Android
/// `GoogleSignInOutcome`. Cancellation is deliberately *not* an error: the user
/// dismissing the sheet should leave the form exactly as it was.
enum SocialSignInOutcome: Sendable {
    /// The user picked an account; the token is ready to POST to the backend.
    case success(token: String, name: String?)
    /// The user dismissed the picker — treat as a no-op.
    case cancelled
    /// Something went wrong; `message` is safe to show the user.
    case failure(String)
}

/// Runs Google sign-in via the official SDK and returns a Google **ID token** to
/// hand to `TapcardAPI.googleSignIn`.
///
/// The account picker is presented UI, so this is `@MainActor` and needs the
/// active window's root view controller.
///
/// The client ID comes from `GIDClientID` in Info.plist — Google's **iOS** OAuth
/// client, not the web one. (Android differs here: Credential Manager wants the
/// *web* client ID.) Either way the minted token's `aud` is that client ID, and
/// the backend's `GOOGLE_MOBILE_CLIENT_IDS` must list it.
@MainActor
enum GoogleAuthService {

    /// True when the app was built with a Google client ID configured. The UI
    /// hides the button entirely rather than offering one that always fails.
    static var isConfigured: Bool { clientID != nil }

    private static var clientID: String? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            return nil
        }
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        // An unsubstituted build setting leaves the literal "$(...)" behind —
        // and an unset env var at `xcodegen generate` time leaves "${...}".
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$("), !trimmed.hasPrefix("${") else { return nil }
        return trimmed
    }

    static func signIn() async -> SocialSignInOutcome {
        guard let clientID else {
            return .failure("Google sign-in isn't set up yet. Try email instead.")
        }
        guard let presenter = rootViewController else {
            return .failure("Couldn't present Google sign-in. Try again.")
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                return .failure("Google didn't return a sign-in token. Try again.")
            }
            return .success(token: idToken, name: result.user.profile?.name)
        } catch let error as NSError {
            if error.code == GIDSignInError.canceled.rawValue {
                return .cancelled
            }
            return .failure("Google sign-in failed. Try again.")
        }
    }

    /// The topmost view controller of the active foreground scene — where the
    /// Google sheet gets presented from.
    private static var rootViewController: UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let root = (scene?.keyWindow ?? scene?.windows.first)?.rootViewController
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
