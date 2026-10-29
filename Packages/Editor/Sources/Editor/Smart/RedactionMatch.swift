/// One thing Smart Redact found in a line of text: what it is and where in the text, as UTF-16 offsets (so it maps
/// onto `NSString` ranges and text measurement).
nonisolated struct RedactionMatch: Sendable, Equatable {
    let category: RedactionCategory
    let location: Int
    let length: Int

    var end: Int {
        location + length
    }

    /// How much of this match `other` covers, 0…1.
    func overlap(with other: RedactionMatch) -> Double {
        let shared = min(end, other.end) - max(location, other.location)
        guard shared > 0, length > 0 else { return 0 }
        return Double(shared) / Double(length)
    }
}
