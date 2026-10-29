import AppKit

/// A volume's capacity as a bar: used space, then purgeable space (striped lighter: macOS frees it when needed), then
/// what is free. Orange when the volume is nearly full.
final class CapacityBarView: NSView {
    var usage: VolumeUsage? {
        didSet {
            needsDisplay = true
            updateAccessibility()
        }
    }

    /// Drawn in white, for a selected row's accent background.
    var isEmphasized = false {
        didSet {
            needsDisplay = true
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.levelIndicator)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 6)
    }

    override func draw(_: NSRect) {
        let track = bounds.insetBy(dx: 0.5, dy: 0.5)
        let radius = track.height / 2
        let trackPath = NSBezierPath(roundedRect: track, xRadius: radius, yRadius: radius)
        (isEmphasized ? NSColor.white.withAlphaComponent(0.3) : NSColor.quaternaryLabelColor).setFill()
        trackPath.fill()
        guard let usage, usage.total > 0 else { return }
        NSGraphicsContext.saveGraphicsState()
        trackPath.addClip()
        let usedWidth = track.width * usage.fraction(usage.usedWithoutPurgeable)
        let purgeableWidth = track.width * usage.fraction(usage.purgeable)
        let used = isEmphasized ? NSColor.white : usage.isNearlyFull ? NSColor.systemOrange : NSColor.controlAccentColor
        used.setFill()
        CGRect(x: track.minX, y: track.minY, width: usedWidth, height: track.height).fill()
        used.withAlphaComponent(isEmphasized ? 0.55 : 0.35).setFill()
        CGRect(x: track.minX + usedWidth, y: track.minY, width: purgeableWidth, height: track.height).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func updateAccessibility() {
        guard let usage else { return }
        setAccessibilityLabel("\(DiskFormat.bytes(usage.used)) used of \(DiskFormat.bytes(usage.total))")
        setAccessibilityValue(NSNumber(value: usage.fraction(usage.used)))
    }
}
