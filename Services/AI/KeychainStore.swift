import Foundation
#if canImport(Security)
import Security
#endif

/// Thread-safe storage for Cloud AI API keys in the device Keychain with in-memory test fallback.
public final class KeychainStore: @unchecked Sendable {
    public static let shared = KeychainStore()

    private let service = "com.skyd3n.orchard.ai"
    private let apiKeyAccount = "cloud_llm_api_key"
    private let endpointAccount = "cloud_llm_endpoint"

    private let inMemory: Bool
    private var inMemoryStorage: [String: String] = [:]
    private let lock = NSLock()

    public init(inMemory: Bool = false) {
        self.inMemory = inMemory
    }

    public func saveAPIKey(_ key: String) {
        lock.lock()
        defer { lock.unlock() }

        if inMemory {
            inMemoryStorage[apiKeyAccount] = key
            return
        }

        #if canImport(Security)
        saveToKeychain(account: apiKeyAccount, value: key)
        #else
        inMemoryStorage[apiKeyAccount] = key
        #endif
    }

    public func getAPIKey() -> String? {
        lock.lock()
        defer { lock.unlock() }

        if inMemory {
            return inMemoryStorage[apiKeyAccount]
        }

        #if canImport(Security)
        return loadFromKeychain(account: apiKeyAccount)
        #else
        return inMemoryStorage[apiKeyAccount]
        #endif
    }

    public func deleteAPIKey() {
        lock.lock()
        defer { lock.unlock() }

        if inMemory {
            inMemoryStorage.removeValue(forKey: apiKeyAccount)
            return
        }

        #if canImport(Security)
        deleteFromKeychain(account: apiKeyAccount)
        #else
        inMemoryStorage.removeValue(forKey: apiKeyAccount)
        #endif
    }

    // MARK: - Keychain Security Wrapper

    #if canImport(Security)
    private func saveToKeychain(account: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Remove existing item before writing
        deleteFromKeychain(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadFromKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        guard status == errSecSuccess, let data = dataTypeRef as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
    #endif
}
