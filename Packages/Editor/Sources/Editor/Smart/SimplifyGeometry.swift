import CoreGraphics

/// Where Simplify's bar goes for a line of text: as long as the line, about as tall as its lower-case letters,
/// centred on it, with round ends. Pure, in image space.
nonisolated enum SimplifyGeometry {
    /// The bar's height as a fraction of the line box's height.
    static let heightFraction: CGFloat = 0.42
    static let minimumHeight: CGFloat = 2

    static func bar(for line: CGRect) -> CGRect {
        let line = line.standardized
        let height = max(minimumHeight, line.height * heightFraction)
        // Line boxes reach from the capitals' tops to the descenders, so the letters' middle is a little below the
        // box's.
        let middle = line.midY + line.height * 0.04
        let width = max(line.width, height)
        return CGRect(x: line.minX, y: middle - height / 2, width: width, height: height)
    }
}
