import Foundation
import Security
import LocalAuthentication

/// Minimal Keychain wrapper for storing the account credentials issued by the
/// backend on first onboarding. Values are kept out of UserDefaults.
enum KeychainStore {
    private static let service = "com.tertiaryinfotech.tapcard.account"

    static func set(_ value: String, for key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// A separate token protected by the current enrolled biometrics. Adding a
    /// new face/fingerprint invalidates access and requires account sign-in.
    static func setBiometricToken(_ token: String) throws {
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(nil,
                    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                    .biometryCurrentSet, &error) else {
            throw APIError.server("Couldn't secure the session on this device.")
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "biometricToken",
            kSecValueData as String: Data(token.utf8),
            kSecAttrAccessControl as String: access
        ]
        delete("biometricToken")
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
            throw APIError.server("Couldn't enable biometric login. Try again.")
        }
    }

    static var hasBiometricToken: Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "biometricToken",
            kSecReturnAttributes as String: true,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    static func biometricToken(context: LAContext) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "biometricToken",
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: context,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data, let token = String(data: data, encoding: .utf8) else {
            throw APIError.server("Your saved login is unavailable. Sign in with your account again.")
        }
        return token
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
