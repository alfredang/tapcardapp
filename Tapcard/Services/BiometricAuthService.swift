import LocalAuthentication
import Foundation

@MainActor
enum BiometricAuthService {
    static var label: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType == .touchID ? "Touch ID" : "Face ID"
    }
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }
    static func authenticate() async throws -> LAContext {
        let context = LAContext()
        context.localizedFallbackTitle = ""
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            throw APIError.server("Biometric authentication is unavailable. Enable Face ID or Touch ID in device Settings, or sign in with your account.")
        }
        try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                         localizedReason: "Unlock your Tapcard account")
        return context
    }
}
