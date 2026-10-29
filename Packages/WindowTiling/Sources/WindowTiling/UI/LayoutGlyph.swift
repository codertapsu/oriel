import AppKit

/// The small pictures in the Window Tiling menu: a screen with the action's part filled in. They are drawn from the
/// geometry the actions themselves use (`TileLayout`), on a model screen, so a picture can never disagree with what
/// the action does. Template images, so they follow the menu's colors in light and dark and when highlighted. Actions
/// that are not a part of the screen use their SF Symbol.
enum LayoutGlyph {
    /// The image's size in points: a 16:10 screen, about as tall as menu text.
    static let size = CGSize(width: 19, height: 13)

    /// A 16:10 model screen; the window that Maximize Height and Center start from sits in its middle.
    private nonisolated static let screen = CGRect(x: 0, y: 0, width: 160, height: 100)
    private nonisolated static let window = CGRect(x: 52, y: 26, width: 56, height: 48)

    static func image(for action: TilingAction) -> NSImage? {
        guard let part = part(of: action) else {
            let image = NSImage(systemSymbolName: action.symbol, accessibilityDescription: action.title)
            return image?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .regular))
        }
        let image = NSImage(size: size, flipped: true) { bounds in
            draw(part, in: bounds)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = action.title
        return image
    }

    /// The action's part of the model screen, as fractions of it (0…1 on each axis, y going down); nil for the actions
    /// that are not a part of the screen.
    nonisolated static func part(of action: TilingAction) -> CGRect? {
        let display = DisplayGeometry(id: 0, frame: screen, visibleFrame: screen)
        // At 90 %, Almost Maximize would look like Maximize at this size, so its picture uses the smallest setting.
        let options = TilingOptions(almostMaximizeFraction: TilingOptions.almostMaximizeRange.lowerBound)
        guard action != .smaller, action != .larger,
              let placement = TileLayout.placement(for: action, window: window, on: display, options: options)
        else { return nil }
        let frame = placement.frame
        return CGRect(
            x: frame.minX / screen.width,
            y: frame.minY / screen.height,
            width: frame.width / screen.width,
            height: frame.height / screen.height
        )
    }

    /// Called by AppKit whenever the image is drawn, on whatever thread draws it.
    private nonisolated static func draw(_ part: CGRect, in bounds: CGRect) {
        NSColor.black.set()
        let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 2.5, yRadius: 2.5)
        outline.lineWidth = 1
        outline.stroke()
        let inner = bounds.insetBy(dx: 2.5, dy: 2.5)
        let fill = CGRect(
            x: inner.minX + part.minX * inner.width,
            y: inner.minY + part.minY * inner.height,
            width: part.width * inner.width,
            height: part.height * inner.height
        ).insetBy(dx: 0.25, dy: 0.25)
        NSBezierPath(roundedRect: fill, xRadius: 1, yRadius: 1).fill()
    }
}
