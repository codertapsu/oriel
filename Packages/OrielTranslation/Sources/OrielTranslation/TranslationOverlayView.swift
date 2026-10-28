import AppKit

/// The in-place overlay (PLAN §7.7.6): the frozen capture with each translated block painted over its box, filled with
/// the sampled background. Hold ⌥ to peek at the original, Esc closes, ⌘1…⌘9 switch providers, and a click copies
/// a block's translation.
@MainActor
final class TranslationOverlayView: NSView {
    private let model: TranslationSessionModel
    private let image: NSImage
    private var cache: [Int: (key: String, layout: OverlayBlockLayout)] = [:]
    private var isPeeking = false {
        didSet {
            if isPeeking != oldValue {
                needsDisplay = true
            }
        }
    }

    var onClose: (@MainActor () -> Void)?
    var onProviderShortcut: (@MainActor (Int) -> Void)?
    var onCopyBlock: (@MainActor (TranslationBlock) -> Void)?

    init(model: TranslationSessionModel) {
        self.model = model
        let cgImage = model.capture.image
        image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Translation overlay")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool {
        true
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    /// Called whenever the model changed.
    func refresh() {
        setAccessibilityValue(model.allTranslations)
        needsDisplay = true
    }

    override func draw(_: NSRect) {
        image.draw(
            in: bounds,
            from: .zero,
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high.rawValue]
        )
        guard !isPeeking else { return }
        OverlayRenderer.draw(layouts())
        if model.isBusy {
            drawPendingOutlines()
        }
    }

    /// The translated blocks in view points, fitted once per text and view size. On screen a block waits for its
    /// sampled colours (they take a moment after OCR), so it never flashes in the fallback colours; exports use the
    /// fallback for anything not sampled yet.
    func layouts(waitingForColors: Bool = true) -> [OverlayBlockLayout] {
        let pointsPerPixel = bounds.width / CGFloat(max(1, model.capture.image.width))
        let rightToLeft = LanguageCatalog.isRightToLeft(model.targetLanguage)
        var layouts: [OverlayBlockLayout] = []
        var visionOnly: [String] = []
        for block in model.blocks {
            guard let translation = block.translation else { continue }
            guard let box = block.box else {
                visionOnly.append(translation)
                continue
            }
            guard let colors = model.colors[block.id] ?? (waitingForColors ? nil : .fallback) else { continue }
            layouts.append(layout(
                id: block.id,
                text: translation,
                box: box,
                lineCount: block.lineCount,
                pointsPerPixel: pointsPerPixel,
                colors: colors,
                rightToLeft: rightToLeft
            ))
        }
        let cardColors = model.colors[TranslationSessionModel.wholeImageID] ?? (waitingForColors ? nil : .fallback)
        if !visionOnly.isEmpty, let colors = cardColors {
            // Text that only AI Vision found has no box: show it on a card over the whole capture.
            let inset = 8 / max(pointsPerPixel, 0.01)
            let box = CGRect(x: 0, y: 0, width: model.capture.image.width, height: model.capture.image.height).insetBy(dx: inset, dy: inset)
            let text = visionOnly.joined(separator: "\n")
            layouts.append(layout(
                id: TranslationSessionModel.wholeImageID,
                text: text,
                box: box,
                lineCount: max(1, visionOnly.count),
                pointsPerPixel: pointsPerPixel,
                colors: colors,
                rightToLeft: rightToLeft
            ))
        }
        return layouts
    }

    private func layout(
        id: Int,
        text: String,
        box: CGRect,
        lineCount: Int,
        pointsPerPixel: CGFloat,
        colors: BlockColors,
        rightToLeft: Bool
    ) -> OverlayBlockLayout {
        let key = "\(text)|\(bounds.size.width)x\(bounds.size.height)|\(colors.background.red),\(colors.text.red)"
        if let cached = cache[id], cached.key == key {
            return cached.layout
        }
        let layout = OverlayBlockLayout.make(
            id: id, text: text, box: box, lineCount: lineCount, pointsPerPixel: pointsPerPixel, colors: colors, rightToLeft: rightToLeft
        )
        cache[id] = (key, layout)
        return layout
    }

    private func drawPendingOutlines() {
        let pointsPerPixel = bounds.width / CGFloat(max(1, model.capture.image.width))
        let path = NSBezierPath()
        for block in model.blocks where block.translation == nil || model.colors[block.id] == nil {
            guard let box = block.box else { continue }
            let rect = CGRect(
                x: box.minX * pointsPerPixel,
                y: box.minY * pointsPerPixel,
                width: box.width * pointsPerPixel,
                height: box.height * pointsPerPixel
            )
            path.append(NSBezierPath(roundedRect: rect.insetBy(dx: -1, dy: -1), xRadius: 3, yRadius: 3))
        }
        NSColor.controlAccentColor.withAlphaComponent(0.7).setStroke()
        path.lineWidth = 1.5
        path.setLineDash([4, 3], count: 2, phase: 0)
        path.stroke()
    }

    // MARK: - Input

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onClose?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func cancelOperation(_: Any?) {
        onClose?()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.numericPad, .function])
        guard modifiers == .command, let digit = event.charactersIgnoringModifiers.flatMap(Int.init), (1 ... 9).contains(digit) else {
            return super.performKeyEquivalent(with: event)
        }
        onProviderShortcut?(digit)
        return true
    }

    override func flagsChanged(with event: NSEvent) {
        isPeeking = event.modifierFlags.contains(.option)
        super.flagsChanged(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let layout = layouts().last(where: { $0.frame.contains(point) }) else { return }
        let block = model.blocks.first { $0.id == layout.id }
            ?? TranslationBlock(id: layout.id, source: "", box: nil, lineCount: 1, translation: layout.text)
        onCopyBlock?(block)
    }
}
