//
//  InstallIdentity.swift
//  MigraineIQ
//
//  Generates and stores a stable per-install UUID in the iOS Keychain.
//  Sent as the X-Install-Id header so the proxy can rate-limit per install
//  without knowing anything about the user's identity.
//
//  The Keychain item uses .afterFirstUnlockThisDeviceOnly accessibility,
//  so the UUID:
//    - persists across app updates
//    - persists across app reinstalls (Keychain survives uninstall by default)
//    - is NOT included in iCloud Keychain sync (single-device scoped)
//

import Foundation
import Security

enum InstallIdentity {
    private static let service = "com.codevibelab.migraineiq.identity"
    private static let account = "install_id"

    /// Returns the install UUID, generating one on first call.
    static var current: String {
        if let existing = read() { return existing }
        let new = UUID().uuidString
        write(new)
        return new
    }

    // MARK: - Keychain --------------------------------------------------

    private static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    private static func write(_ value: String) {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(baseQuery as CFDictionary)

        var add = baseQuery
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}
