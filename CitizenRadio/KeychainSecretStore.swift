#if os(iOS)
import Foundation
import Security
#if SWIFT_PACKAGE
import CitizenRadioCore
#endif

/// Stores the wallet connection URI in the Keychain.
/// ADR 0007 §Storage names these rules.
/// Each Keychain call runs in a dispatch queue block, off the main thread.
final class KeychainSecretStore: SecretStore {
    private enum UpdateResult: Equatable {
        case updated
        case notFound
    }

    private let service: String
    private let account: String
    private let queue = DispatchQueue(label: "org.citizenradio.CitizenRadio.keychain")

    init(service: String = "org.citizenradio.CitizenRadio.nwc", account: String = "default") {
        self.service = service
        self.account = account
    }

    func read() async throws -> String? {
        guard let data = try await copyData() else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func write(_ value: String) async throws {
        let data = Data(value.utf8)
        let result = try await updateItem(with: data)
        guard result == .notFound else { return }
        try await addItem(with: data)
    }

    func delete() async throws {
        try await deleteItem()
    }

    // MARK: - Keychain calls, each in its own dispatch queue block

    private func copyData() async throws -> Data? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data?, Error>) in
            queue.async {
                var item: CFTypeRef?
                let status = SecItemCopyMatching(self.searchQuery(returningData: true) as CFDictionary, &item)
                switch status {
                case errSecSuccess: continuation.resume(returning: item as? Data)
                case errSecItemNotFound: continuation.resume(returning: nil)
                default: continuation.resume(throwing: KeychainError(status: status))
                }
            }
        }
    }

    private func updateItem(with data: Data) async throws -> UpdateResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UpdateResult, Error>) in
            queue.async {
                let status = SecItemUpdate(self.searchQuery() as CFDictionary, [kSecValueData as String: data] as CFDictionary)
                switch status {
                case errSecSuccess: continuation.resume(returning: .updated)
                case errSecItemNotFound: continuation.resume(returning: .notFound)
                default: continuation.resume(throwing: KeychainError(status: status))
                }
            }
        }
    }

    private func addItem(with data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                var query = self.searchQuery()
                query[kSecValueData as String] = data
                query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
                let status = SecItemAdd(query as CFDictionary, nil)
                switch status {
                case errSecSuccess: continuation.resume()
                default: continuation.resume(throwing: KeychainError(status: status))
                }
            }
        }
    }

    private func deleteItem() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                let status = SecItemDelete(self.searchQuery() as CFDictionary)
                switch status {
                case errSecSuccess, errSecItemNotFound: continuation.resume()
                default: continuation.resume(throwing: KeychainError(status: status))
                }
            }
        }
    }

    /// The query that finds the one item this store owns.
    /// The item is a local, non-synchronizable generic password.
    private func searchQuery(returningData: Bool = false) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
        if returningData {
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
        }
        return query
    }
}

/// An error from a Keychain call. It holds only the status number. It does not hold the secret.
struct KeychainError: Error, LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        "The Keychain returned status \(status)."
    }
}
#endif
