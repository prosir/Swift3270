import Foundation
import Security

enum PassphraseKeychain {
    private static let service = "Swift3270.saved-passphrase"

    static func save(_ passphrase: String, for profileID: String) throws {
        guard !passphrase.isEmpty else {
            try delete(for: profileID)
            return
        }

        let data = Data(passphrase.utf8)
        let lookup = baseQuery(for: profileID)
        let update = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(lookup as CFDictionary, update as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var item = lookup
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw PassphraseKeychainError(status: addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw PassphraseKeychainError(status: updateStatus)
        }
    }

    static func load(for profileID: String) throws -> String? {
        var query = baseQuery(for: profileID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let data = result as? Data,
              let passphrase = String(data: data, encoding: .utf8) else {
            throw PassphraseKeychainError(status: status)
        }
        return passphrase
    }

    static func delete(for profileID: String) throws {
        let status = SecItemDelete(baseQuery(for: profileID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PassphraseKeychainError(status: status)
        }
    }

    private static func baseQuery(for profileID: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profileID,
            kSecAttrSynchronizable as String: false
        ]
    }
}

struct PassphraseKeychainError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return "Sleutelhanger: \(message)"
        }
        return "Sleutelhangerfout (\(status))"
    }
}
