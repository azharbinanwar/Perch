//
//  LRUCache.swift
//  Perch
//
//  Tiny least-recently-used cache: keeps at most `capacity` entries, evicting the
//  oldest-touched when full. O(n) touch, but n is small (tens), so it's cheap.
//

// A struct (not a class) on purpose: the Swift optimizer crashes specializing a generic
// class's implicit deinit when archiving Release builds — structs have no deinit at all.
struct LRUCache<Key: Hashable, Value> {
    private let capacity: Int
    private var store: [Key: Value] = [:]
    private var order: [Key] = []          // least-recently-used first

    init(capacity: Int) { self.capacity = max(1, capacity) }

    mutating func value(for key: Key) -> Value? {
        guard let value = store[key] else { return nil }
        touch(key)
        return value
    }

    mutating func set(_ value: Value, for key: Key) {
        store[key] = value
        touch(key)
        while order.count > capacity {
            store[order.removeFirst()] = nil
        }
    }

    private mutating func touch(_ key: Key) {
        order.removeAll { $0 == key }
        order.append(key)
    }
}
