import Foundation

/// One entry of Clipboard History: what describes and finds it. Its contents are stored apart, encrypted, and read
/// only to preview, paste or drag it.
nonisolated struct ClipboardItem: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    var kind: ClipboardKind
    /// One line for the list: the first line of text, the file names, "Screenshot · 2880 × 1800".
    var title: String
    /// Plain text to search and show: the text itself, a link, a color, file paths. Capped at
    /// `ClipboardClassifier.textLimit` characters; the whole text is in the contents.
    var text: String?
    var sourceName: String?
    var sourceBundleID: String?
    var firstCopied: Date
    var lastCopied: Date
    var copyCount: Int
    /// SHA-256 of the main content. A copy with the same hash is the same item copied again.
    var contentHash: String
    var byteCount: Int
    var pixelWidth: Int?
    var pixelHeight: Int?
    var fileURLs: [URL]?
    /// "#RRGGBB", or "#RRGGBBAA" when not opaque.
    var colorHex: String?
    /// Text Vision found in an image: nil until read, empty when there was none.
    var recognizedText: String?
    var hasThumbnail: Bool

    init(
        id: UUID = UUID(),
        classification: ClipboardClassifier.Result,
        byteCount: Int,
        sourceName: String?,
        sourceBundleID: String?,
        date: Date,
        hasThumbnail: Bool = false
    ) {
        self.id = id
        kind = classification.kind
        title = classification.title
        text = classification.text
        self.sourceName = sourceName
        self.sourceBundleID = sourceBundleID
        firstCopied = date
        lastCopied = date
        copyCount = 1
        contentHash = classification.contentHash
        self.byteCount = byteCount
        pixelWidth = classification.pixelWidth
        pixelHeight = classification.pixelHeight
        fileURLs = classification.fileURLs
        colorHex = classification.colorHex
        recognizedText = nil
        self.hasThumbnail = hasThumbnail
    }

    /// Takes a repeat copy's description, source and date, keeping this item's identity, first date and read text.
    mutating func absorb(_ copy: ClipboardItem) {
        kind = copy.kind
        title = copy.title
        text = copy.text
        sourceName = copy.sourceName
        sourceBundleID = copy.sourceBundleID
        lastCopied = max(lastCopied, copy.lastCopied)
        copyCount += 1
        byteCount = copy.byteCount
        pixelWidth = copy.pixelWidth
        pixelHeight = copy.pixelHeight
        fileURLs = copy.fileURLs
        colorHex = copy.colorHex
        hasThumbnail = hasThumbnail || copy.hasThumbnail
    }
}
