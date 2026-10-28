import CoreGraphics

/// The fill and text colour of one overlay block, sampled once from the capture.
struct BlockColors: Equatable, Sendable {
    let background: RGBColor
    let text: RGBColor

    static let fallback = BlockColors(background: .white, text: .black)

    /// Samples every box: the background is the median of a 2 px ring around the box, the text keeps the original
    /// text colour when it is readable on that background and is black or white otherwise.
    static func sample(_ boxes: [Int: CGRect], in buffer: PixelBuffer) -> [Int: BlockColors] {
        boxes.mapValues { box in
            let background = BackgroundSampler.background(around: box, in: buffer)
            let original = BackgroundSampler.foreground(in: box, of: buffer, background: background)
            return BlockColors(background: background, text: RGBColor.readableText(on: background, preferring: original))
        }
    }
}
