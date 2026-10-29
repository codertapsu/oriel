nonisolated extension Array {
    /// The element at `index`, or nil when the index is out of range.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
