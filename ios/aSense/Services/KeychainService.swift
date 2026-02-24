import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()
    private let service = "com.momstudios.asense"
    private let aesKeyAccount = "aes-key"
    private let deviceIDAccount = "device-uuid"
    private let apiTokenAccount = "api-token"

    private init() {}

    // MARK: - Public

    func ensureKeysExist() {
        if loadData(account: aesKeyAccount) == nil {
            var bytes = [UInt8](repeating: 0, count: 32)
            let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            guard status == errSecSuccess else { return }
            save(data: Data(bytes), account: aesKeyAccount)
        }
        if loadData(account: deviceIDAccount) == nil {
            let uuid = UUID().uuidString
            save(data: Data(uuid.utf8), account: deviceIDAccount)
        }
    }

    var aesKeyData: Data? {
        loadData(account: aesKeyAccount)
    }

    var aesKeyBase64: String? {
        aesKeyData?.base64EncodedString()
    }

    var deviceUUID: String? {
        guard let data = loadData(account: deviceIDAccount) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    var apiToken: String? {
        get {
            guard let data = loadData(account: apiTokenAccount) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            if let value = newValue {
                save(data: Data(value.utf8), account: apiTokenAccount)
            }
        }
    }

    // MARK: - Keychain helpers

    private func save(data: Data, account: String) {
        let searchQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(searchQuery as CFDictionary)

        var addQuery = searchQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func loadData(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
}
