import AppKit

/// A share as a short bar with its percentage, for the Size column: the biggest items stand out at a glance.
final class SizeBarView: NSView {
    var fraction: Double = 0 {
        didSet {
            needsDisplay = true
        }
    }

    var tint: NSColor = .controlAccentColor {
        didSet {
            needsDisplay = true
        }
    }

    override func draw(_: NSRect) {
        let track = CGRect(x: 0, y: (bounds.height - 6) / 2, width: bounds.width, height: 6)
        NSColor.quaternaryLabelColor.setFill()
        NSBezierPath(roundedRect: track, xRadius: 3, yRadius: 3).fill()
        let width = max(fraction > 0 ? 2 : 0, track.width * min(1, max(0, fraction)))
        tint.setFill()
        NSBezierPath(roundedRect: CGRect(x: track.minX, y: track.minY, width: width, height: track.height), xRadius: 3, yRadius: 3).fill()
    }
}
