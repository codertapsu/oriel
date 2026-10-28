import CoreGraphics

/// The result of a headless translation, for `oriel translate area --json` (PLAN §13.5).
public struct TranslationOutcome: Codable, Sendable, Equatable {
    /// One OCR block and its translation.
    public struct Block: Codable, Sendable, Equatable {
        public let id: Int
        public let source: String
        /// Nil when the provider returned nothing for this block.
        public let translation: String?
        public let box: Box

        public init(id: Int, source: String, translation: String?, box: Box) {
            self.id = id
            self.source = source
            self.translation = translation
            self.box = box
        }
    }

    /// A block's bounding box in the image's pixels, top-left origin.
    public struct Box: Codable, Sendable, Equatable {
        public let x: Double
        public let y: Double
        public let width: Double
        public let height: Double

        public init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }

        public init(_ rect: CGRect) {
            self.init(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
        }
    }

    public let providerID: String
    /// BCP 47; nil when it could not be detected and the provider detected it itself.
    public let sourceLanguage: String?
    public let targetLanguage: String
    public let blocks: [Block]

    public init(providerID: String, sourceLanguage: String?, targetLanguage: String, blocks: [Block]) {
        self.providerID = providerID
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.blocks = blocks
    }
}
