/// Decodes a value or, when that fails, nothing, so one unreadable entry in a list does not lose the rest of the file.
nonisolated struct Lenient<Value: Decodable & Sendable>: Decodable, Sendable {
    let value: Value?

    init(from decoder: any Decoder) throws {
        value = try? Value(from: decoder)
    }
}
