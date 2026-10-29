import CoreGraphics
import CoreText
import Foundation
import SharedUI

/// Exports a step sequence as one tall PNG (PLAN §17): the title, then every step under a numbered header with its
/// heading and note, on white. Images are drawn one at a time from disk, and the pixel scale is lowered for a sequence
/// that would otherwise be too large (`StepSheetLayout`).
nonisolated enum StepSheetExporter {
    // Computed: Core Text fonts are not Sendable, so they cannot be shared constants.
    static var titleFont: CTFont {
        StepTypesetter.font(size: 24, bold: true)
    }

    static var subtitleFont: CTFont {
        StepTypesetter.font(size: 13)
    }

    static var headingFont: CTFont {
        StepTypesetter.font(size: 17, bold: true)
    }

    static var noteFont: CTFont {
        StepTypesetter.font(size: 14)
    }

    /// Writes the PNG to `url` and returns its size in pixels.
    @discardableResult
    static func export(_ items: [StepExportItem], title: String, subtitle: String, accent: CGColor, to url: URL) throws -> CGSize {
        let width = StepSheetLayout.width(for: items.map(\.pointSize))
        let content = width - 2 * StepSheetLayout.margin
        let textWidth = StepSheetLayout.textWidth(sheetWidth: width)
        let titleText = heading(title: title, subtitle: subtitle)
        let headings = items.map { StepTypesetter.text($0.heading, font: headingFont, color: StepTypesetter.primary) }
        let notes = items.map { StepTypesetter.text($0.note, font: noteFont, color: StepTypesetter.secondary) }
        let layout = StepSheetLayout(
            width: width,
            titleHeight: StepTypesetter.height(of: titleText, width: content),
            imageSizes: items.map(\.pointSize),
            textHeights: zip(headings, notes).map { heading, note in
                (StepTypesetter.height(of: heading, width: textWidth), StepTypesetter.height(of: note, width: textWidth))
            }
        )
        let scale = layout.scale(preferred: min(2, items.map(\.scale).max() ?? 2))
        let pixels = layout.pixelSize(scale: scale)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: Int(pixels.width),
                  height: Int(pixels.height),
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: space,
                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              )
        else {
            throw CaptureError.failed("The sequence is too large for one image. Export it as PDF or HTML instead.")
        }
        context.scaleBy(x: scale, y: scale)
        context.interpolationQuality = .high
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: layout.width, height: layout.height))
        let canvas = layout.height
        StepTypesetter.draw(titleText, in: layout.title, canvasHeight: canvas, context: context)
        for (index, block) in layout.blocks.enumerated() {
            let item = items[index]
            drawBadge(item.number, in: block.badge, accent: accent, canvasHeight: canvas, context: context)
            StepTypesetter.draw(headings[index], in: block.heading, canvasHeight: canvas, context: context)
            if let note = block.note {
                StepTypesetter.draw(notes[index], in: note, canvasHeight: canvas, context: context)
            }
            try autoreleasepool {
                guard let image = StepImageRenderer.image(for: item) else {
                    throw CaptureError.failed("The image of step \(item.number) could not be read.")
                }
                let frame = StepTypesetter.flipped(block.image, canvasHeight: canvas)
                context.draw(image, in: frame)
                context.setStrokeColor(StepTypesetter.separator)
                context.setLineWidth(1)
                context.stroke(frame.insetBy(dx: -0.5, dy: -0.5))
            }
        }
        guard let sheet = context.makeImage() else { throw CaptureError.failed("The sequence could not be drawn.") }
        try ImageFile.write(sheet, to: url, format: .png, scale: scale)
        return pixels
    }

    /// The title above its subtitle.
    static func heading(title: String, subtitle: String) -> NSAttributedString {
        let text = NSMutableAttributedString(attributedString: StepTypesetter.text(title, font: titleFont, color: StepTypesetter.primary))
        if !subtitle.isEmpty {
            text.append(StepTypesetter.text("\n\(subtitle)", font: subtitleFont, color: StepTypesetter.secondary))
        }
        return text
    }

    /// A filled circle in the accent colour with the step's number in white.
    static func drawBadge(_ number: Int, in rect: CGRect, accent: CGColor, canvasHeight: CGFloat, context: CGContext) {
        context.setFillColor(accent)
        context.fillEllipse(in: StepTypesetter.flipped(rect, canvasHeight: canvasHeight))
        let size: CGFloat = number < 100 ? 14 : 11
        let text = StepTypesetter.text("\(number)", font: StepTypesetter.font(size: size, bold: true), color: CGColor(gray: 1, alpha: 1))
        StepTypesetter.drawCentred(text, at: CGPoint(x: rect.midX, y: rect.midY), canvasHeight: canvasHeight, context: context)
    }
}
