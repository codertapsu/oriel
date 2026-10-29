/// Recent Translate Under Cursor results, by text and context, the least recently used going first.
struct CursorCache: Sendable {
    let limit: Int
    private var values: [String: CursorTranslation] = [:]
    private var order: [String] = []

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    var count: Int {
        values.count
    }

    /// The cached result, now the most recently used.
    mutating func use(_ key: String) -> CursorTranslation? {
        guard let value = values[key] else { return nil }
        order.removeAll { $0 == key }
        order.append(key)
        return value
    }

    subscript(key: String) -> CursorTranslation? {
        get {
            values[key]
        }
        set {
            order.removeAll { $0 == key }
            guard let newValue else {
                values[key] = nil
                return
            }
            values[key] = newValue
            order.append(key)
            while order.count > limit {
                values[order.removeFirst()] = nil
            }
        }
    }
}
