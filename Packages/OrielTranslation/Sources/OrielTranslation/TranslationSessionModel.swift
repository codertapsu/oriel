import CoreGraphics
import Foundation
import Observation
import OrielCore

/// The state of one open translation, shared by the overlay, its toolbar and the side panel. The coordinator writes
/// it; SwiftUI views observe it directly and the AppKit overlay through `withObservationTracking`.
@MainActor
@Observable
final class TranslationSessionModel {
    enum Phase: Equatable {
        case recognizing
        case translating
        case finished
        case failed(String)
    }

    /// One entry of the provider pop-up.
    struct ProviderChoice: Identifiable, Equatable {
        let id: ProviderID
        let name: String
        let capabilities: ProviderCapabilities
    }

    let capture: CaptureResult
    private(set) var blocks: [TranslationBlock] = []
    /// Sampled once per capture; blocks without colours yet are drawn as pending.
    var colors: [Int: BlockColors] = [:]
    var providerID: ProviderID
    var providers: [ProviderChoice] = []
    var sourceLanguage: Locale.Language?
    var targetLanguage: Locale.Language
    var phase: Phase = .recognizing
    var isOffline = false
    var usesImageInput = false
    /// A remark under the status, for example "Already in English".
    var note: String?

    init(capture: CaptureResult, providerID: ProviderID, targetLanguage: Locale.Language) {
        self.capture = capture
        self.providerID = providerID
        self.targetLanguage = targetLanguage
    }

    /// Pseudo block id for the colours of the whole capture, used for text that only AI Vision found.
    nonisolated static let wholeImageID = 0

    var provider: ProviderChoice? {
        providers.first { $0.id == providerID }
    }

    var targetCode: String {
        LanguageCatalog.code(for: targetLanguage)
    }

    var translatedCount: Int {
        blocks.count { $0.translation != nil }
    }

    var isBusy: Bool {
        phase == .recognizing || phase == .translating
    }

    var segments: [TranslationSegment] {
        blocks.filter { $0.box != nil }.map { TranslationSegment(id: $0.id, text: $0.source) }
    }

    /// Every translation, in block order, separated by blank lines (for Copy All and the TXT export).
    var allTranslations: String {
        blocks.compactMap(\.translation).joined(separator: "\n\n")
    }

    var statusText: String {
        switch phase {
        case .recognizing: "Recognizing text…"
        case .translating: "Translating… \(translatedCount)/\(max(blocks.count, translatedCount))"
        case .finished: note ?? "\(LanguageCatalog.name(of: targetCode)) · \(provider?.name ?? providerID.rawValue)"
        case let .failed(message): message
        }
    }

    func setBlocks(_ ocrBlocks: [OCRBlock]) {
        blocks = ocrBlocks.map { TranslationBlock(id: $0.id, source: $0.text, box: $0.boundingBox, lineCount: $0.lineCount) }
    }

    /// Drops every translation (and AI Vision's box-less blocks) before translating again.
    func clearTranslations() {
        blocks = blocks.filter { $0.box != nil }.map { block in
            var block = block
            block.translation = nil
            return block
        }
        note = nil
    }

    /// Fills a block. Unknown ids are text AI Vision found by itself; they are kept, without a box, when they carry
    /// their source text.
    func apply(_ segment: TranslatedSegment) {
        if let index = blocks.firstIndex(where: { $0.id == segment.id }) {
            blocks[index].translation = segment.text
        } else if usesImageInput, segment.id >= SegmentPrompt.firstVisionOnlyID {
            blocks.append(TranslationBlock(id: segment.id, source: segment.source ?? "", box: nil, lineCount: 1, translation: segment.text))
        }
    }
}
