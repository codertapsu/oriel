/// One copy Oriel made to the general pasteboard, as `Pasteboard.writes()` announces it.
public nonisolated struct PasteboardWrite: Sendable {
    public let snapshot: PasteboardSnapshot
    /// The pasteboard's change count right after the write.
    public let changeCount: Int
    /// What was copied, such as "Screenshot", where the contents alone would not say.
    public let label: String?

    public init(snapshot: PasteboardSnapshot, changeCount: Int, label: String? = nil) {
        self.snapshot = snapshot
        self.changeCount = changeCount
        self.label = label
    }
}
