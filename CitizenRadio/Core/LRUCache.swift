import Foundation

/// A cache with a fixed capacity. The cache removes its oldest entry first.
/// ADR 0008 §Artwork names this rule for the artwork cache.
public struct LRUCache<Key: Hashable & Sendable, Value: Sendable>: Sendable {
    private let capacity: Int
    private var storage: [Key: Value] = [:]
    /// The keys from oldest to most recent.
    private var order: [Key] = []

    public init(capacity: Int) {
        self.capacity = capacity
    }

    /// The number of entries in the cache.
    public var count: Int {
        storage.count
    }

    /// Gives the value for the key, and marks the key as the most recent.
    /// Gives nil when the key is not in the cache.
    public mutating func value(for key: Key) -> Value? {
        guard let value = storage[key] else {
            return nil
        }
        markMostRecent(key)
        return value
    }

    /// Stores the value for the key as the most recent entry.
    /// Removes the oldest entry when the cache is full.
    /// Stores nothing when the capacity is 0 or less.
    public mutating func insert(_ value: Value, for key: Key) {
        guard capacity > 0 else {
            return
        }

        if storage[key] != nil {
            storage[key] = value
            markMostRecent(key)
            return
        }

        storage[key] = value
        order.append(key)

        if order.count > capacity {
            let oldestKey = order.removeFirst()
            storage.removeValue(forKey: oldestKey)
        }
    }

    private mutating func markMostRecent(_ key: Key) {
        if let index = order.firstIndex(of: key) {
            order.remove(at: index)
        }
        order.append(key)
    }
}
