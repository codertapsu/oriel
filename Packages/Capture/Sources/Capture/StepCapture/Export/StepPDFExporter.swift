import CoreGraphics
import CoreText
import Foundation
import PDFKit

/// Exports a step sequence as a PDF (PLAN §17): one step per page, its numbered heading and note above the image,
/// with the sequence's title and "Step 3 of 12" in a running header. Pages are A4 or US Letter, in landscape for a
/// wide capture. Core Graphics draws the pages, so the text is real and selectable; PDFKit then adds a bookmark for
/// every step and the document's title.
nonisolated enum StepPDFExporter {
    static let a4 = CGSize(width: 595, height: 842)
    static let letter = CGSize(width: 612, height: 792)
    static let margin: CGFloat = 48

    /// US Letter where it is the custom, A4 elsewhere.
    static func paperSize(for locale: Locale) -> CGSize {
        let letterRegions: Set = ["US", "CA", "MX", "PH", "CL", "CO", "VE", "PR", "GT", "CR", "PA", "DO", "SV", "NI", "HN"]
        return locale.region.map { letterRegions.contains($0.identifier) } == true ? letter : a4
    }

    /// The page for an image of `size` (points): landscape when it is clearly wider than tall.
    static func page(for size: CGSize, paper: CGSize) -> CGSize {
        size.width > size.height * 1.15 ? CGSize(width: paper.height, height: paper.width) : paper
    }

    static func export(_ items: [StepExportItem], title: String, accent: CGColor, paper: CGSize, to url: URL) throws {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { throw CaptureError.failed("The PDF could not be started.") }
        var mediaBox = CGRect(origin: .zero, size: paper)
        let info: [CFString: Any] = [kCGPDFContextTitle: title, kCGPDFContextCreator: "Oriel"]
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, info as CFDictionary) else {
            throw CaptureError.failed("The PDF could not be started.")
        }
        for item in items {
            try autoreleasepool {
                guard let image = StepImageRenderer.image(for: item) else {
                    throw CaptureError.failed("The image of step \(item.number) could not be read.")
                }
                let size = page(for: item.pointSize, paper: paper)
                var box = CGRect(origin: .zero, size: size)
                let boxData = Data(bytes: &box, count: MemoryLayout<CGRect>.size)
                context.beginPDFPage([kCGPDFContextMediaBox: boxData] as CFDictionary)
                drawPage(item, of: items.count, image: image, title: title, accent: accent, size: size, context: context)
                context.endPDFPage()
            }
        }
        context.closePDF()
        // A document opened from data writes no outline added to it afterwards (macOS 27.0.1), so the pages move to a
        // new one first.
        guard let drawn = PDFDocument(data: data as Data) else { throw CaptureError.failed("The PDF could not be read back.") }
        let document = PDFDocument()
        for index in 0 ..< drawn.pageCount {
            if let page = drawn.page(at: index) {
                document.insert(page, at: document.pageCount)
            }
        }
        addOutline(to: document, items: items)
        document.documentAttributes = [
            PDFDocumentAttribute.titleAttribute: title,
            PDFDocumentAttribute.creatorAttribute: "Oriel",
        ]
        guard let output = document.dataRepresentation() else { throw CaptureError.failed("The PDF could not be written.") }
        try output.write(to: url, options: .atomic)
    }

    private static func drawPage(
        _ item: StepExportItem,
        of total: Int,
        image: CGImage,
        title: String,
        accent: CGColor,
        size: CGSize,
        context: CGContext
    ) {
        let canvas = size.height
        let content = CGRect(x: margin, y: margin, width: size.width - 2 * margin, height: size.height - 2 * margin)
        let small = StepTypesetter.font(size: 9)
        let running = StepTypesetter.text(title, font: small, color: StepTypesetter.secondary)
        let counter = StepTypesetter.text("Step \(item.number) of \(total)", font: small, color: StepTypesetter.secondary)
        let counterWidth = CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(counter), nil, nil, nil)).rounded(.up) + 2
        StepTypesetter.draw(
            running,
            in: CGRect(x: content.minX, y: content.minY, width: content.width - counterWidth - 12, height: 14),
            canvasHeight: canvas,
            context: context
        )
        StepTypesetter.draw(
            counter,
            in: CGRect(x: content.maxX - counterWidth, y: content.minY, width: counterWidth, height: 14),
            canvasHeight: canvas,
            context: context
        )
        context.setStrokeColor(StepTypesetter.separator)
        context.setLineWidth(0.5)
        context.strokeLineSegments(between: [
            CGPoint(x: content.minX, y: canvas - content.minY - 20),
            CGPoint(x: content.maxX, y: canvas - content.minY - 20),
        ])

        let badge = CGRect(x: content.minX, y: content.minY + 36, width: 26, height: 26)
        StepSheetExporter.drawBadge(item.number, in: badge, accent: accent, canvasHeight: canvas, context: context)
        let textX = badge.maxX + 12
        let textWidth = content.maxX - textX
        let heading = StepTypesetter.text(item.heading, font: StepTypesetter.font(size: 17, bold: true), color: StepTypesetter.primary)
        let headingHeight = min(StepTypesetter.height(of: heading, width: textWidth), content.height * 0.2)
        let headingY = headingHeight < badge.height ? badge.minY + ((badge.height - headingHeight) / 2).rounded() : badge.minY
        let headingFrame = CGRect(x: textX, y: headingY, width: textWidth, height: headingHeight)
        StepTypesetter.draw(heading, in: headingFrame, canvasHeight: canvas, context: context)
        var bottom = max(badge.maxY, headingFrame.maxY)
        if !item.note.isEmpty {
            let note = StepTypesetter.text(item.note, font: StepTypesetter.font(size: 12), color: StepTypesetter.secondary)
            let noteHeight = min(StepTypesetter.height(of: note, width: textWidth), content.height * 0.3)
            let noteFrame = CGRect(x: textX, y: headingFrame.maxY + 6, width: textWidth, height: noteHeight)
            StepTypesetter.draw(note, in: noteFrame, canvasHeight: canvas, context: context)
            bottom = max(bottom, noteFrame.maxY)
        }

        let area = CGRect(x: content.minX, y: bottom + 18, width: content.width, height: content.maxY - bottom - 18)
        let frame = fitted(item.pointSize, in: area)
        let flipped = StepTypesetter.flipped(frame, canvasHeight: canvas)
        context.interpolationQuality = .high
        context.draw(image, in: flipped)
        context.setStrokeColor(StepTypesetter.separator)
        context.setLineWidth(0.5)
        context.stroke(flipped.insetBy(dx: -0.25, dy: -0.25))
    }

    /// `size` scaled to fit `area` (never up), centred horizontally at its top.
    static func fitted(_ size: CGSize, in area: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0, area.width > 0, area.height > 0 else { return .zero }
        let factor = min(1, area.width / size.width, area.height / size.height)
        let width = size.width * factor
        let height = size.height * factor
        return CGRect(x: area.minX + (area.width - width) / 2, y: area.minY, width: width, height: height)
    }

    /// A bookmark per step, "3. Open Settings", that opens its page.
    private static func addOutline(to document: PDFDocument, items: [StepExportItem]) {
        let root = PDFOutline()
        document.outlineRoot = root
        for (index, item) in items.enumerated() {
            guard let page = document.page(at: index) else { continue }
            let entry = PDFOutline()
            entry.label = "\(item.number). \(item.heading)"
            entry.destination = PDFDestination(page: page, at: CGPoint(x: 0, y: page.bounds(for: .mediaBox).maxY))
            root.insertChild(entry, at: root.numberOfChildren)
        }
    }
}
