import CoreGraphics
import Foundation
import Observation
import OrielCore

/// The state of the file translation window (PLAN §17): the file's segments as they are read, their translations as
/// they arrive, the provider and languages, and for an image the translated picture. The coordinator writes it; the
/// AppKit window follows it through observation tracking.
@MainActor
@Observable
final class FileTranslationModel {
    enum Phase: Equatable {
        /// No file yet: the window shows where to drop one.
        case idle
        case reading
        case translating
        case finished
        case cancelled
        case failed(String)
    }

    private(set) var url: URL?
    private(set) var kind: DocumentKind?
    private(set) var segments: [DocumentSegment] = []
    private(set) var translations: [Int: String] = [:]
    /// Bumped on every change to the segments or translations, so the table reloads only when it must.
    private(set) var revision = 0
    var phase = Phase.idle
    /// A remark instead of the usual status, for example "Already in English".
    var note: String?
    /// Whether every part of the file has been read.
    var isComplete = false
    var currentPage: Int?
    var pageCount: Int?
    var subtitleHeader: String?
    var usedOCR = false

    var providerID: ProviderID
    var providers: [TranslationSessionModel.ProviderChoice] = []
    var targetLanguage: Locale.Language
    var sourceLanguage: Locale.Language?

    /// An image file and its OCR blocks, and the translation drawn over it.
    var image: CGImage?
    var imageBlocks: [OCRBlock] = []
    /// Each block's background and text colour, sampled once from the image.
    var imageColors: [Int: BlockColors] = [:]
    var annotatedImage: CGImage?
    var showsOriginalImage = false

    init(providerID: ProviderID, targetLanguage: Locale.Language) {
        self.providerID = providerID
        self.targetLanguage = targetLanguage
    }

    var targetCode: String {
        LanguageCatalog.code(for: targetLanguage)
    }

    var provider: TranslationSessionModel.ProviderChoice? {
        providers.first { $0.id == providerID }
    }

    var isBusy: Bool {
        phase == .reading || phase == .translating
    }

    var translatableCount: Int {
        segments.count(where: \.isTranslatable)
    }

    var translatedCount: Int {
        segments.count { $0.isTranslatable && translations[$0.id] != nil }
    }

    var characterCount: Int {
        segments.reduce(0) { $0 + ($1.isTranslatable ? $1.text.count : 0) }
    }

    /// The window's title: the file's name.
    var title: String {
        url?.lastPathComponent ?? "Translate File"
    }

    /// "Markdown · 42 paragraphs · English → Japanese".
    var summary: String {
        guard let kind else { return "" }
        var parts = [kind.title]
        if let pageCount, pageCount > 0 {
            parts.append("\(pageCount.formatted()) \(pageCount == 1 ? "page" : "pages")")
        }
        parts.append(kind.count(translatableCount))
        let languages = [
            sourceLanguage.map { LanguageCatalog.name(of: LanguageCatalog.code(for: $0)) },
            LanguageCatalog.name(of: targetCode),
        ]
        parts.append(languages.compactMap(\.self).joined(separator: " → "))
        if usedOCR {
            parts.append("read with OCR")
        }
        return parts.joined(separator: " · ")
    }

    var statusText: String {
        guard let kind else { return "Files stay on this Mac; only their text goes to the translation provider." }
        let progress = "\(translatedCount.formatted()) of \(kind.count(translatableCount)) translated"
        switch phase {
        case .idle:
            return ""
        case .reading:
            if let currentPage, let pageCount {
                return "Reading page \(currentPage.formatted()) of \(pageCount.formatted())…"
            }
            return "Reading \(title)…"
        case .translating:
            let page = currentPage.flatMap { page in pageCount.map { " · page \(page.formatted()) of \($0.formatted())" } } ?? ""
            return "Translating… \(progress)\(page)"
        case .finished:
            return note ?? "Translated \(kind.count(translatedCount)) with \(provider?.name ?? providerID.rawValue)"
        case .cancelled:
            return "Stopped · \(progress)"
        case let .failed(message):
            return translatedCount > 0 ? "\(message) (\(progress))" : message
        }
    }

    // MARK: - Changes

    /// Starts over with a new file.
    func open(_ url: URL, kind: DocumentKind) {
        self.url = url
        self.kind = kind
        segments = []
        translations = [:]
        note = nil
        isComplete = false
        currentPage = nil
        pageCount = nil
        subtitleHeader = nil
        usedOCR = false
        sourceLanguage = nil
        image = nil
        imageBlocks = []
        imageColors = [:]
        annotatedImage = nil
        showsOriginalImage = false
        phase = .reading
        revision &+= 1
    }

    /// Reads the same file again, keeping the translations it has: segment ids depend only on the file, so they
    /// come back to the same segments (Resume after a stop during reading).
    func reopen() {
        segments = []
        isComplete = false
        currentPage = nil
        note = nil
        phase = .reading
        revision &+= 1
    }

    /// A file Oriel cannot translate: the window says why.
    func refuse(_ url: URL, message: String) {
        self.url = url
        kind = nil
        segments = []
        translations = [:]
        phase = .failed(message)
        revision &+= 1
    }

    func append(_ part: DocumentPart) {
        segments += part.segments
        currentPage = part.page ?? currentPage
        pageCount = part.pageCount ?? pageCount
        subtitleHeader = part.subtitleHeader ?? subtitleHeader
        usedOCR = usedOCR || part.usedOCR
        if let image = part.image {
            self.image = image
            imageBlocks = part.blocks
        }
        revision &+= 1
    }

    func setTranslation(_ text: String, for segmentID: Int) {
        guard translations[segmentID] != text else { return }
        translations[segmentID] = text
        revision &+= 1
    }

    func clearTranslations() {
        translations = [:]
        annotatedImage = nil
        note = nil
        revision &+= 1
    }

    /// The translation or, for a segment kept as it is, the original.
    func shownTranslation(of segment: DocumentSegment) -> String? {
        segment.verbatim ?? translations[segment.id]
    }
}
