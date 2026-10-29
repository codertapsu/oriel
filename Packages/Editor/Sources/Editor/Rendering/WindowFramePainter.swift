import CoreGraphics

/// The window frame's title bar: a flat bar in the light or dark window colour, a hairline under it, and the
/// close, minimise and zoom lights. Fixed colours, so the export looks the same whatever the Mac's appearance.
enum WindowFramePainter {
    private static let lights: [(fill: RGBAColor, edge: RGBAColor)] = [
        (BackgroundPreset.rgb(0xFF5F57), BackgroundPreset.rgb(0xE0443E)),
        (BackgroundPreset.rgb(0xFEBC2E), BackgroundPreset.rgb(0xDEA123)),
        (BackgroundPreset.rgb(0x28C840), BackgroundPreset.rgb(0x1AAB29)),
    ]

    /// Draws into `rect` (canvas space, y down); the caller clips to the card's rounded corners.
    static func draw(_ frame: WindowFrame, in rect: CGRect, context: CGContext) {
        guard frame != .none, rect.height > 0 else { return }
        let (bar, hairline) = colors(for: frame)
        context.saveGState()
        defer { context.restoreGState() }
        context.setFillColor(bar.cgColor)
        context.fill(rect)
        context.setFillColor(hairline.cgColor)
        context.fill(CGRect(x: rect.minX, y: rect.maxY - 0.5, width: rect.width, height: 0.5))
        let diameter = WindowFrame.lightDiameter
        for (index, light) in lights.enumerated() {
            let x = rect.minX + WindowFrame.lightInset + CGFloat(index) * (diameter + WindowFrame.lightSpacing)
            let circle = CGRect(x: x, y: rect.midY - diameter / 2, width: diameter, height: diameter)
            context.setFillColor(light.fill.cgColor)
            context.fillEllipse(in: circle)
            context.setStrokeColor(light.edge.cgColor)
            context.setLineWidth(0.5)
            context.strokeEllipse(in: circle.insetBy(dx: 0.25, dy: 0.25))
        }
    }

    /// The bar and its hairline, like a macOS window in that appearance.
    static func colors(for frame: WindowFrame) -> (bar: RGBAColor, hairline: RGBAColor) {
        switch frame {
        case .dark: (RGBAColor(red: 0.17, green: 0.17, blue: 0.18), RGBAColor(red: 0, green: 0, blue: 0, alpha: 0.55))
        case .light, .none: (RGBAColor(red: 0.93, green: 0.93, blue: 0.94), RGBAColor(red: 0, green: 0, blue: 0, alpha: 0.12))
        }
    }
}
