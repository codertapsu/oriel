import CoreGraphics
import Foundation

/// Turns recognized lines into Smart Redact's finds and, once the user has reviewed them, into blur or pixelate
/// regions. Pure.
nonisolated enum RedactionPlanner {
    /// Padding around each find, as a fraction of its line's height, and at least `minimumPadding` points.
    static let paddingFraction: CGFloat = 0.18
    static let minimumPadding: CGFloat = 2

    /// Every find in `lines`, one box per stretch of text, joined with its neighbours of the same category. A PEM
    /// private-key header hides the key's lines below it too, up to its END line.
    static func findings(in lines: [TextLine]) -> [RedactionFinding] {
        var boxes: [RedactionCategory: [CGRect]] = [:]
        var insidePrivateKey = false
        for line in lines {
            let padding = max(minimumPadding, line.rect.height * paddingFraction)
            if insidePrivateKey {
                if isPrivateKeyBody(line.text) {
                    boxes[.secret, default: []].append(line.rect.insetBy(dx: -padding, dy: -padding))
                    insidePrivateKey = !line.text.uppercased().contains("END")
                    continue
                }
                insidePrivateKey = false
            }
            for match in RedactionDetector.matches(in: line.text) {
                let box = TextSpanEstimator.box(
                    location: match.location,
                    length: match.length,
                    in: line.text,
                    lineBox: line.rect,
                    padding: padding
                )
                boxes[match.category, default: []].append(box)
                if match.category == .secret, line.text.uppercased().contains("PRIVATE KEY"), line.text.uppercased().contains("BEGIN") {
                    insidePrivateKey = true
                }
            }
        }
        return RedactionCategory.allCases.flatMap { category in
            BoxMerger.merge(boxes[category] ?? [], tolerance: 1).map { RedactionFinding(category: category, rect: $0) }
        }
    }

    /// How many finds of each category there are.
    static func counts(_ findings: [RedactionFinding]) -> [RedactionCategory: Int] {
        findings.reduce(into: [:]) { $0[$1.category, default: 0] += 1 }
    }

    /// The regions that hide the finds of `categories`: overlapping finds become one region, strong enough for the
    /// size of the text it covers, and clipped to `bounds` (the visible image).
    static func regions(
        for findings: [RedactionFinding],
        categories: Set<RedactionCategory>,
        effect: RedactionEffect,
        in bounds: CGRect
    ) -> [AnnotationItem] {
        let rects = BoxMerger.merge(findings.filter { categories.contains($0.category) }.map(\.rect), tolerance: 0)
        return rects.compactMap { rect in
            let clipped = rect.intersection(bounds)
            guard !clipped.isNull, clipped.width > 0, clipped.height > 0 else { return nil }
            let region = Region(rect: clipped, amount: strength(for: clipped, effect: effect))
            return effect == .blur ? .blur(region) : .pixelate(region)
        }
    }

    /// Blur radius or block size for a region: enough that text of its height cannot be read, and never weaker than
    /// the blur tool's default.
    static func strength(for rect: CGRect, effect: RedactionEffect) -> CGFloat {
        let height = rect.height
        switch effect {
        case .blur: return max(ToolStyle.effectAmount(ToolStyle.defaultWidth), (height * 0.55).rounded())
        case .pixelate: return max(8, (height * 0.45).rounded())
        }
    }

    /// A line of a PEM key's body: base64 only, or its END line.
    private static func isPrivateKeyBody(_ text: String) -> Bool {
        let compact = text.filter { !$0.isWhitespace }
        if compact.uppercased().contains("END"), compact.uppercased().contains("KEY") {
            return true
        }
        return compact.count >= 16 && compact.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "+/=".contains($0)) }
    }
}
