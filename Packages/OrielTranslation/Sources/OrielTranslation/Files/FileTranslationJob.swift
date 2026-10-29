import Foundation

/// The provider side of one file translation, settled once the first text is read: which provider, its limits,
/// whether there is anything to do (text already in the target language is not sent), and the pieces of long
/// paragraphs as their translations come back.
@MainActor
final class FileTranslationJob {
    let generation: Int
    var config: ProviderConfig?
    var provider: (any TranslationProvider)?
    var limits = ChunkLimits(maxSegments: 40, maxCharacters: 6000, maxSegmentCharacters: 3000)
    /// Set once the provider was checked and, for long files with a provider that bills, the user agreed.
    var isReady = false
    /// The text is already in the target language.
    var isSameLanguage = false
    var nextRequestID = 1
    /// Segment id → piece number → translation, for paragraphs translated in pieces.
    private var pieces: [Int: [Int: String]] = [:]

    init(generation: Int) {
        self.generation = generation
    }

    /// Records one piece and returns the segment's translation so far, the pieces joined in order.
    func add(_ text: String, piece: DocumentChunker.Piece, target: Locale.Language) -> String {
        pieces[piece.segmentID, default: [:]][piece.part] = text
        let parts = pieces[piece.segmentID, default: [:]].sorted { $0.key < $1.key }.map(\.value)
        return DocumentChunker.join(parts, target: target)
    }
}
