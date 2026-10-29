import CoreGraphics
@testable import WindowTiling

/// Display arrangements like the dev Mac's, written as `NSScreen` reports them (Cocoa coordinates, y going up) and
/// converted as `DisplayReader` converts them: the built-in display is the primary one, with the Dock at the bottom,
/// on the left or on the right, and external displays sit to the left, to the right, above and below it, at other
/// sizes, one of them portrait and one at an odd width.
enum Displays {
    static let primaryHeight: CGFloat = 982

    /// The built-in 1512×982 display: a 33-point menu bar (the notch) and a 70-point Dock at the bottom.
    /// Accessibility: frame (0, 0, 1512, 982), visible (0, 33, 1512, 879).
    static let laptop = make(1, frame: CGRect(x: 0, y: 0, width: 1512, height: 982), visible: CGRect(x: 0, y: 70, width: 1512, height: 879))
    /// The Dock on the left, 64 points wide. Visible (64, 33, 1448, 949).
    static let laptopDockLeft = make(1, frame: laptopCocoa, visible: CGRect(x: 64, y: 0, width: 1448, height: 949))
    /// The Dock on the right. Visible (0, 33, 1448, 949).
    static let laptopDockRight = make(1, frame: laptopCocoa, visible: CGRect(x: 0, y: 0, width: 1448, height: 949))
    /// A 2560×1440 display to the right, top edges aligned, with a 25-point menu bar. Visible (1512, 25, 2560, 1415).
    static let right = make(
        2,
        frame: CGRect(x: 1512, y: -458, width: 2560, height: 1440),
        visible: CGRect(x: 1512, y: -458, width: 2560, height: 1415)
    )
    /// A 1920×1080 display to the left, bottom edges aligned: above the primary's top in Accessibility's coordinates.
    /// Frame (-1920, -98, 1920, 1080), visible (-1920, -73, 1920, 1055).
    static let left = make(
        3,
        frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
        visible: CGRect(x: -1920, y: 0, width: 1920, height: 1055)
    )
    /// A 2560×1440 display above, centered over the primary. Frame (-524, -1440, 2560, 1440), visible (-524, -1415, …).
    static let above = make(
        4,
        frame: CGRect(x: -524, y: 982, width: 2560, height: 1440),
        visible: CGRect(x: -524, y: 982, width: 2560, height: 1415)
    )
    /// A 1365×768 display below, at an odd width, so halves need rounding. Visible (73, 1007, 1365, 743).
    static let below = make(
        5,
        frame: CGRect(x: 73, y: -768, width: 1365, height: 768),
        visible: CGRect(x: 73, y: -768, width: 1365, height: 743)
    )
    /// A 1080×1920 portrait display to the right. Visible (1512, 25, 1080, 1895).
    static let portrait = make(
        6,
        frame: CGRect(x: 1512, y: -938, width: 1080, height: 1920),
        visible: CGRect(x: 1512, y: -938, width: 1080, height: 1895)
    )

    /// Every single display, for the tests that hold on each.
    static let all = [laptop, laptopDockLeft, laptopDockRight, right, left, above, below, portrait]
    /// Three displays side by side: left, laptop, right.
    static let row = [laptop, left, right]

    private static let laptopCocoa = CGRect(x: 0, y: 0, width: 1512, height: 982)

    private static func make(_ id: UInt32, frame: CGRect, visible: CGRect) -> DisplayGeometry {
        DisplayGeometry(id: id, cocoaFrame: frame, cocoaVisibleFrame: visible, primaryHeight: primaryHeight)
    }
}
