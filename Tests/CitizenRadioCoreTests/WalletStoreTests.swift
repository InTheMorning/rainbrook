import Foundation
import XCTest
@testable import CitizenRadioCore

/// An in-memory fake of `SecretStore`, for tests.
private actor FakeSecretStore: SecretStore {
    private var value: String?

    func read() async throws -> String? {
        value
    }

    func write(_ value: String) async throws {
        self.value = value
    }

    func delete() async throws {
        value = nil
    }
}

final class WalletStoreTests: XCTestCase {
    private func sampleConnection() throws -> NWCConnection {
        let key = String(repeating: "a", count: 64)
        let secret = String(repeating: "b", count: 64)
        return try NWCConnection(uri: "nostr+walletconnect://\(key)?relay=wss://relay.example.com&secret=\(secret)")
    }

    func testNoStoredValueGivesNilConnection() async throws {
        let store = WalletStore(secrets: FakeSecretStore())
        let connection = try await store.connection()
        XCTAssertNil(connection)
    }

    func testSaveThenConnectionGivesAnEqualConnection() async throws {
        let store = WalletStore(secrets: FakeSecretStore())
        let connection = try sampleConnection()
        try await store.save(connection)
        let read = try await store.connection()
        XCTAssertEqual(read, connection)
    }

    func testRemoveThenConnectionGivesNil() async throws {
        let store = WalletStore(secrets: FakeSecretStore())
        try await store.save(try sampleConnection())
        try await store.remove()
        let read = try await store.connection()
        XCTAssertNil(read)
    }

    func testAStoredValueThatDoesNotParseGivesNil() async throws {
        let secrets = FakeSecretStore()
        try await secrets.write("not a connection uri")
        let store = WalletStore(secrets: secrets)
        let read = try await store.connection()
        XCTAssertNil(read)
    }
}
