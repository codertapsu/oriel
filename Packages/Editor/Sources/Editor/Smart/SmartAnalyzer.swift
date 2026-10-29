import CoreGraphics
import Foundation
import OrielCore

/// The smart tools' work, off the main thread (PLAN §17): OCR through the app's `TextRecognizing` (lines, the finest
/// boxes it gives), detection, and the pixel work of lifting objects and erasing text. Everything runs on this Mac,
/// and nothing that was read is logged. The lines of the latest image are kept, so Smart Redact, Simplify and
/// Smart Move read the text once between them.
actor SmartAnalyzer {
    enum Failure: Error, Equatable {
        case noTextRecognition
    }

    /// Whether the app gave Oriel a text recognizer; without one, only Smart Move's objects and regions work.
    nonisolated let canReadText: Bool
    private let recognizer: (any TextRecognizing)?
    private var cache: (imageID: UUID, lines: [TextLine])?
    private let log = Log.logger("editor")

    init(recognizer: (any TextRecognizing)?) {
        self.recognizer = recognizer
        canReadText = recognizer != nil
    }

    /// The lines of text in `base`, in image space.
    func textLines(in base: ImageRef) async throws -> [TextLine] {
        if let cache, cache.imageID == base.id {
            return cache.lines
        }
        guard let recognizer else { throw Failure.noTextRecognition }
        let blocks = try await recognizer.recognize(base.image, mode: .fast, languages: [])
        try Task.checkCancellation()
        let lines = blocks.map { TextLine($0, scale: base.scale) }
        cache = (base.id, lines)
        log.info("Smart tools read \(lines.count, privacy: .public) lines of text")
        return lines
    }

    /// What Smart Redact would hide in the `visible` part of `base`.
    func redactions(in base: ImageRef, visible: CGRect) async throws -> [RedactionFinding] {
        let lines = try await textLines(in: base).filter { $0.rect.intersects(visible) }
        let findings = RedactionPlanner.findings(in: lines).filter { $0.rect.intersects(visible) }
        log.info("Smart Redact found \(findings.count, privacy: .public) places to hide")
        return findings
    }

    /// Simplify's bars and patches for the lines of text in the `visible` part of `base`.
    func simplification(in base: ImageRef, visible: CGRect) async throws -> SimplifyPlan {
        let lines = try await textLines(in: base).filter { visible.contains(CGPoint(x: $0.rect.midX, y: $0.rect.midY)) }
        try Task.checkCancellation()
        return SimplifyPlanner.plan(lines: lines, base: base)
    }

    /// The objects Smart Move can lift in the `visible` part of `base`: blocks of text, then foreground objects, then
    /// salient regions, each kept only if it does not overlap one kept before it. Overlapping objects would carry
    /// each other's pixels: moving one would leave a copy of the other behind.
    func movableObjects(in base: ImageRef, visible: CGRect) async throws -> (objects: [MovableObject], objectsUnavailable: Bool) {
        var rects: [(rect: CGRect, mask: MaskGrid?, source: ImageLayer.Source)] = []
        if canReadText {
            let lines = try await textLines(in: base).filter { visible.contains(CGPoint(x: $0.rect.midX, y: $0.rect.midY)) }
            rects += LineGrouping.blocks(lines.map(\.rect)).map { ($0, nil, .text) }
        }
        try Task.checkCancellation()
        let detections = ObjectDetector.detect(in: base.image)
        let size = CGSize(width: base.image.width, height: base.image.height)
        for grid in detections.objects {
            guard let box = grid.boundingBox(in: size) else { continue }
            let rect = Self.pointRect(box.cgRect, scale: base.scale)
            if !Self.overlapsAny(rect, rects.map(\.rect)) {
                rects.append((rect, grid, .object))
            }
        }
        for region in detections.regions {
            let rect = Self.pointRect(region, scale: base.scale)
            if !Self.overlapsAny(rect, rects.map(\.rect)) {
                rects.append((rect, nil, .region))
            }
        }
        try Task.checkCancellation()
        let objects = rects
            .filter { visible.intersects($0.rect) }
            .prefix(60)
            .compactMap { ObjectLifter.lift($0.rect.intersection(visible), mask: $0.mask, from: base, source: $0.source) }
            .filter { $0.source == .text || ObjectLifter.hasContent($0) }
        log.info("Smart Move found \(objects.count, privacy: .public) objects")
        return (objects, detections.objectsUnavailable)
    }

    private static func pointRect(_ pixels: CGRect, scale: CGFloat) -> CGRect {
        CGRect(x: pixels.minX / scale, y: pixels.minY / scale, width: pixels.width / scale, height: pixels.height / scale)
    }

    /// Whether `rect` shares more than a sliver (a tenth of the smaller one's area) with any of `others`.
    static func overlapsAny(_ rect: CGRect, _ others: [CGRect]) -> Bool {
        others.contains { other in
            let shared = rect.intersection(other)
            guard !shared.isNull else { return false }
            let smaller = min(rect.width * rect.height, other.width * other.height)
            return smaller <= 0 || shared.width * shared.height > smaller * 0.1
        }
    }
}
