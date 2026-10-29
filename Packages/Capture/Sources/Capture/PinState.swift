import CoreGraphics
import Foundation

/// How a pinned capture looks and behaves (PLAN §10.4, §17): its opacity and zoom, click-through, the position lock
/// and the border with its shadow. Pure, so the rules are unit-tested; `Pin` applies it to its panel.
nonisolated struct PinState: Sendable, Equatable {
    static let opacities: ClosedRange<CGFloat> = 0.1 ... 1
    static let zooms: ClosedRange<CGFloat> = 0.1 ... 8
    /// ⌘+ and ⌘− go through these.
    static let zoomSteps: [CGFloat] = [0.1, 0.25, 0.33, 0.5, 0.67, 0.75, 1, 1.25, 1.5, 2, 3, 4, 6, 8]
    /// A pin never gets smaller than this on either side, so it can still be grabbed.
    static let minimumSide: CGFloat = 24

    private(set) var opacity: CGFloat = 1
    /// 1 shows the capture at its own point size.
    private(set) var zoom: CGFloat = 1
    var isLocked = false
    /// Clicks go to the window underneath.
    var isClickThrough = false
    /// The border and the shadow, on by default; off, the pin is the bare image.
    var showsBorder = true
    /// A scrolling capture is running, so every pin lets the mouse through.
    var isPassingThrough = false
    /// ⌥⌘ is held with the pointer over a click-through pin, which then takes clicks until they are let go.
    var isHeldOpen = false

    /// Whether the panel lets the mouse through to the window underneath.
    var ignoresMouseEvents: Bool {
        isPassingThrough || (isClickThrough && !isHeldOpen)
    }

    var opacityPercent: Int {
        Int((opacity * 100).rounded())
    }

    var zoomPercent: Int {
        Int((zoom * 100).rounded())
    }

    mutating func setOpacity(_ value: CGFloat) {
        opacity = min(max(value, Self.opacities.lowerBound), Self.opacities.upperBound)
    }

    mutating func changeOpacity(by delta: CGFloat) {
        setOpacity(opacity + delta)
    }

    /// 1 to 9 set 10 to 90 %, 0 sets 100 %, as in a key pressed over the pin.
    static func opacity(forDigit digit: Int) -> CGFloat? {
        guard (0 ... 9).contains(digit) else { return nil }
        return digit == 0 ? 1 : CGFloat(digit) / 10
    }

    mutating func setZoom(_ value: CGFloat) {
        zoom = min(max(value, Self.zooms.lowerBound), Self.zooms.upperBound)
    }

    mutating func zoom(by factor: CGFloat) {
        setZoom(zoom * factor)
    }

    /// The next larger step.
    mutating func zoomIn() {
        setZoom(Self.zoomSteps.first { $0 > zoom + 0.001 } ?? Self.zooms.upperBound)
    }

    /// The next smaller step.
    mutating func zoomOut() {
        setZoom(Self.zoomSteps.last { $0 < zoom - 0.001 } ?? Self.zooms.lowerBound)
    }

    /// The pin's size for a capture of `pointSize`: zoomed, rounded to whole points, and never smaller than
    /// `minimumSide`.
    func size(for pointSize: CGSize) -> CGSize {
        CGSize(
            width: max(Self.minimumSide, (pointSize.width * zoom).rounded()),
            height: max(Self.minimumSide, (pointSize.height * zoom).rounded())
        )
    }

    /// A scroll of `scrollDelta` over the pin zooms by this factor: smoothly with a trackpad (`precise`), in steps of
    /// about 5 % per notch of a mouse wheel.
    static func zoomFactor(scrollDelta: CGFloat, precise: Bool) -> CGFloat {
        exp(scrollDelta * (precise ? 0.005 : 0.05))
    }

    /// ⌥ and a scroll of `scrollDelta` change the opacity by this much: 10 % per notch of a mouse wheel.
    static func opacityChange(scrollDelta: CGFloat, precise: Bool) -> CGFloat {
        precise ? scrollDelta / 300 : scrollDelta / 20
    }

    /// `current` resized to `size` so that `anchor` (the pointer, in the same coordinates) stays over the same point
    /// of the capture; an anchor outside the pin counts as the nearest point on its edge.
    static func frame(of current: CGRect, resizedTo size: CGSize, keeping anchor: CGPoint) -> CGRect {
        guard current.width > 0, current.height > 0 else { return CGRect(origin: current.origin, size: size) }
        // Where the anchor is across and up the pin, from 0 to 1.
        let across = min(max((anchor.x - current.minX) / current.width, 0), 1)
        let up = min(max((anchor.y - current.minY) / current.height, 0), 1)
        let fixed = CGPoint(x: current.minX + across * current.width, y: current.minY + up * current.height)
        let origin = CGPoint(x: (fixed.x - across * size.width).rounded(), y: (fixed.y - up * size.height).rounded())
        return CGRect(origin: origin, size: size)
    }
}
