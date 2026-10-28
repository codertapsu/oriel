import CoreGraphics
@testable import OrielTranslation
import Testing

/// Background sampling, contrast, the annotated image and where the panels go.
struct OverlayTests {
    private typealias Pixel = (red: UInt8, green: UInt8, blue: UInt8)

    /// A `width × height` buffer filled by `color(x, y)`.
    private func buffer(width: Int, height: Int, color: (Int, Int) -> Pixel) -> PixelBuffer {
        var bytes: [UInt8] = []
        for y in 0 ..< height {
            for x in 0 ..< width {
                let pixel = color(x, y)
                bytes += [pixel.red, pixel.green, pixel.blue, 255]
            }
        }
        return PixelBuffer(width: width, height: height, bytes: bytes)
    }

    @Test func pixelBuffersStartAtTheTopRow() throws {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 2, width: 4, height: 2)) // CoreGraphics' upper half
        let image = try #require(context.makeImage())
        let pixels = try #require(PixelBuffer(image: image))
        #expect(pixels.pixel(x: 0, y: 0) == (255, 0, 0))
        #expect(pixels.pixel(x: 3, y: 3) == (0, 0, 255))
    }

    @Test func backgroundIsTheMedianOfTheTwoPixelRingAroundTheBox() {
        let box = CGRect(x: 5, y: 5, width: 10, height: 6)
        let pixels = buffer(width: 20, height: 20) { x, y in
            if box.contains(CGPoint(x: x, y: y)) {
                return y == 7 ? (0, 0, 0) : (255, 255, 255) // white label with a black line of "text"
            }
            return x == 4 && y < 10 ? (255, 0, 0) : (20, 40, 200) // blue, with a little red noise in the ring
        }
        #expect(BackgroundSampler.background(around: box, in: pixels) == RGBColor(bytes: 20, 40, 200))
        let white = BackgroundSampler.background(around: CGRect(x: 7, y: 8, width: 4, height: 2), in: pixels)
        #expect(white == .white)
        let text = BackgroundSampler.foreground(in: box, of: pixels, background: .white)
        #expect(text == .black)
    }

    @Test func boxesCoveringTheWholeImageUseTheBandInsideTheirEdge() {
        let pixels = buffer(width: 10, height: 10) { x, y in
            x < 2 || y < 2 || x > 7 || y > 7 ? (250, 250, 240) : (0, 0, 0)
        }
        let background = BackgroundSampler.background(around: CGRect(x: 0, y: 0, width: 10, height: 10), in: pixels)
        #expect(background == RGBColor(bytes: 250, 250, 240))
    }

    @Test func flatBoxesHaveNoTextColour() {
        let pixels = buffer(width: 8, height: 8) { _, _ in (128, 128, 128) }
        #expect(BackgroundSampler.foreground(
            in: CGRect(x: 1, y: 1, width: 6, height: 6),
            of: pixels,
            background: RGBColor(bytes: 128, 128, 128)
        ) == nil)
    }

    @Test func contrastFollowsWCAGAndKeepsReadableOriginalColours() {
        #expect(abs(RGBColor.white.contrastRatio(with: .black) - 21) < 0.01)
        #expect(abs(RGBColor.white.contrastRatio(with: .white) - 1) < 0.01)
        let darkBlue = RGBColor(bytes: 10, 30, 90)
        let red = RGBColor(bytes: 200, 0, 0)
        let lightGray = RGBColor(bytes: 200, 200, 200)
        #expect(RGBColor.readableText(on: darkBlue, preferring: nil) == .white)
        #expect(RGBColor.readableText(on: .white, preferring: red) == red) // 5.9:1 — kept
        #expect(RGBColor.readableText(on: .white, preferring: lightGray) == .black) // 1.7:1 — replaced
    }

    @MainActor
    @Test func annotatedImagesPaintBlocksAtFullResolution() throws {
        let image = try TestSupport.image(width: 200, height: 100, red: 0, green: 1, blue: 0)
        let colors = BlockColors(background: RGBColor(bytes: 255, 0, 0), text: .white)
        let layout = OverlayBlockLayout.make(
            id: 1, text: " ", box: CGRect(x: 20, y: 20, width: 80, height: 40), lineCount: 1, pointsPerPixel: 0.5, colors: colors,
            rightToLeft: false
        )
        let annotated = try #require(OverlayRenderer.annotatedImage(image, layouts: [layout], pointSize: CGSize(width: 100, height: 50)))
        #expect(annotated.width == 200 && annotated.height == 100)
        let pixels = try #require(PixelBuffer(image: annotated))
        #expect(pixels.pixel(x: 60, y: 40) == (255, 0, 0)) // inside the block
        #expect(pixels.pixel(x: 150, y: 80) == (0, 255, 0)) // outside it
    }

    @Test func toolbarGoesAboveTheOverlayThenBelowThenInside() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let size = CGSize(width: 400, height: 40)
        let middle = OverlayPlacement.toolbarFrame(
            size: size,
            overlay: CGRect(x: 100, y: 300, width: 300, height: 200),
            visibleFrame: screen
        )
        #expect(middle == CGRect(x: 100, y: 508, width: 400, height: 40))
        let top = OverlayPlacement.toolbarFrame(size: size, overlay: CGRect(x: 100, y: 500, width: 300, height: 290), visibleFrame: screen)
        #expect(top.maxY == 492)
        let full = OverlayPlacement.toolbarFrame(size: size, overlay: CGRect(x: 700, y: 0, width: 300, height: 800), visibleFrame: screen)
        #expect(full == CGRect(x: 592, y: 752, width: 400, height: 40))
    }

    @Test func sidePanelGoesBesideTheOverlay() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let size = CGSize(width: 300, height: 500)
        let right = OverlayPlacement.sidePanelFrame(
            size: size,
            overlay: CGRect(x: 100, y: 300, width: 300, height: 400),
            visibleFrame: screen
        )
        #expect(right == CGRect(x: 412, y: 200, width: 300, height: 500))
        let left = OverlayPlacement.sidePanelFrame(
            size: size,
            overlay: CGRect(x: 600, y: 300, width: 300, height: 400),
            visibleFrame: screen
        )
        #expect(left.maxX == 588)
        let wide = OverlayPlacement.sidePanelFrame(size: size, overlay: CGRect(x: 100, y: 0, width: 800, height: 800), visibleFrame: screen)
        #expect(wide.maxX == 988 && wide.maxY == 788)
    }

    @Test func importedCapturesAreCentredAndScaledToFit() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let frame = OverlayPlacement.overlayFrame(captureRect: .zero, pointSize: CGSize(width: 2000, height: 500), visibleFrame: screen)
        #expect(frame == CGRect(x: 50, y: 288, width: 900, height: 225))
        let onScreen = CGRect(x: 10, y: 20, width: 30, height: 40)
        #expect(OverlayPlacement.overlayFrame(captureRect: onScreen, pointSize: .zero, visibleFrame: screen) == onScreen)
    }
}
