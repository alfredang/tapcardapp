import Foundation
import UIKit
import AuthenticationServices

/// Runs Sign in with Apple and returns the **identity token** to hand to
/// `TapcardAPI.appleSignIn`.
///
/// App Store Guideline 4.8 requires an equivalent privacy-preserving login
/// wherever a third-party social login is offered, so this ships alongside
/// Google rather than instead of it.
///
/// Apple hands back the user's real name **only on the very first
/// authorization** and never again, so the name is forwarded to the backend when
/// present — the identity token itself carries no name claim.
@MainActor
final class AppleAuthService: NSObject {

    /// Kept alive for the duration of the request: `ASAuthorizationController`
    /// holds its delegate weakly, so without this the controller is deallocated
    /// mid-flight and the sheet silently never appears.
    private static var active: AppleAuthService?

    private var resume: ((SocialSignInOutcome) -> Void)?

    static func signIn() async -> SocialSignInOutcome {
        let service = AppleAuthService()
        active = service
        let outcome = await service.perform()
        active = nil
        return outcome
    }

    private func perform() async -> SocialSignInOutcome {
        await withCheckedContinuation { continuation in
            // Guard against a double-resume: the delegate contract is one
            // callback, but a continuation resumed twice is a hard crash.
            var finished = false
            resume = { outcome in
                guard !finished else { return }
                finished = true
                continuation.resume(returning: outcome)
            }

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
}

extension AppleAuthService: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let data = credential.identityToken,
              let token = String(data: data, encoding: .utf8) else {
            resume?(.failure("Apple didn't return a sign-in token. Try again."))
            return
        }

        // Present only on first authorization; nil on every later sign-in.
        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        resume?(.success(token: token, name: name.isEmpty ? nil : name))
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        let code = (error as? ASAuthorizationError)?.code
        if code == .canceled {
            resume?(.cancelled)
        } else {
            resume?(.failure("Sign in with Apple failed. Try again."))
        }
    }
}

extension AppleAuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return scene?.keyWindow ?? scene?.windows.first ?? ASPresentationAnchor()
    }
}
