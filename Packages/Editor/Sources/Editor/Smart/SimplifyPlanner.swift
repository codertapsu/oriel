import CoreGraphics

/// Simplify (PLAN §17): every recognized line of text becomes a rounded bar in the text's dominant colour on the
/// background estimated around it, for clean diagrams of screenshots. Pure pixel work, run off the main thread.
nonisolated enum SimplifyPlanner {
    static func plan(lines: [TextLine], base: ImageRef) -> SimplifyPlan {
        var plan = SimplifyPlan.empty
        for line in lines where line.rect.width >= 2 && line.rect.height >= 2 {
            guard let patch = ObjectLifter.erase(line.rect, from: base, source: .text) else { continue }
            let pixels = PixelImage(base.image, region: PixelRect(covering: line.rect, scale: base.scale).cgRect)
            let ink = pixels.flatMap(TextInkEstimator.colors(in:))?.ink.rgbaColor ?? .black
            plan.patches.append(patch)
            plan.bars.append(Bar(rect: SimplifyGeometry.bar(for: line.rect), color: ink.withAlpha(1)))
        }
        return plan
    }
}
