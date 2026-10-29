/// The newest `capacity` values, oldest first: a full buffer overwrites its oldest value instead of growing.
nonisolated struct RingBuffer<Element: Sendable>: Sendable {
    private(set) var capacity: Int
    private var storage: [Element] = []
    /// Where the oldest value is once the buffer is full.
    private var start = 0

    init(capacity: Int) {
        self.capacity = max(1, capacity)
        storage.reserveCapacity(self.capacity)
    }

    var count: Int {
        storage.count
    }

    var isEmpty: Bool {
        storage.isEmpty
    }

    var last: Element? {
        guard !storage.isEmpty else { return nil }
        return storage[(start + storage.count - 1) % storage.count]
    }

    /// Oldest first.
    var elements: [Element] {
        guard start > 0 else { return storage }
        return Array(storage[start...] + storage[..<start])
    }

    mutating func append(_ element: Element) {
        if storage.count < capacity {
            storage.append(element)
        } else {
            storage[start] = element
            start = (start + 1) % capacity
        }
    }

    /// Changes the capacity, keeping the newest values that fit.
    mutating func resize(to newCapacity: Int) {
        let kept = elements.suffix(max(1, newCapacity))
        capacity = max(1, newCapacity)
        storage = Array(kept)
        storage.reserveCapacity(capacity)
        start = 0
    }

    mutating func removeAll() {
        storage.removeAll(keepingCapacity: true)
        start = 0
    }
}
