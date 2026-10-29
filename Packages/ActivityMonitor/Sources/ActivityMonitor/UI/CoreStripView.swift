import AppKit

/// One bar per core, system time (red) under user time (blue), efficiency and performance cores labelled below.
final class CoreStripView: NSView {
    static let barWidth: CGFloat = 7
    static let gap: CGFloat = 3
    static let groupGap: CGFloat = 8
    static let labelHeight: CGFloat = 12

    var cores: [CoreLoad] = [] {
        didSet {
            needsDisplay = true
            invalidateIntrinsicContentSize()
            updateAccessibility()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: max(40, Self.width(of: cores.map(\.type))), height: NSView.noIntrinsicMetric)
    }

    /// The strip's width for these core types: bars, gaps, and a wider gap where the type changes.
    static func width(of types: [CoreType]) -> CGFloat {
        guard !types.isEmpty else { return 0 }
        let changes = zip(types, types.dropFirst()).count { $0 != $1 }
        return CGFloat(types.count) * barWidth + CGFloat(types.count - 1 - changes) * gap + CGFloat(changes) * groupGap
    }

    override func draw(_: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext, !cores.isEmpty else { return }
        let height = bounds.height - Self.labelHeight
        var x = bounds.minX
        var groupStart = x
        let font = NSFont.systemFont(ofSize: 9, weight: .medium)
        for (index, core) in cores.enumerated() {
            if index > 0, cores[index - 1].type != core.type {
                label(cores[index - 1].type, from: groupStart, to: x - Self.gap, font: font)
                x += Self.groupGap - Self.gap
                groupStart = x
            }
            let track = CGRect(x: x, y: Self.labelHeight, width: Self.barWidth, height: height)
            context.setFillColor(NSColor.quaternaryLabelColor.cgColor)
            context.fill(track)
            let systemHeight = height * CGFloat(min(1, core.load.system))
            let userHeight = min(height - systemHeight, height * CGFloat(min(1, core.load.user)))
            context.setFillColor(ActivityColors.system.cgColor)
            context.fill(CGRect(x: x, y: Self.labelHeight, width: Self.barWidth, height: systemHeight))
            context.setFillColor(ActivityColors.user.cgColor)
            context.fill(CGRect(x: x, y: Self.labelHeight + systemHeight, width: Self.barWidth, height: userHeight))
            x += Self.barWidth + Self.gap
        }
        if let last = cores.last {
            label(last.type, from: groupStart, to: x - Self.gap, font: font)
        }
    }

    private func label(_ type: CoreType, from start: CGFloat, to end: CGFloat, font: NSFont) {
        guard !type.letter.isEmpty else { return }
        let text = NSAttributedString(string: type.letter, attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor])
        let size = text.size()
        text.draw(at: CGPoint(x: ((start + end - size.width) / 2).rounded(), y: 0))
    }

    private func updateAccessibility() {
        let busy = cores.map { Int(($0.load.busy * 100).rounded()) }
        setAccessibilityLabel("Per-core load: " + busy.map { "\($0) %" }.joined(separator: ", "))
    }
}
