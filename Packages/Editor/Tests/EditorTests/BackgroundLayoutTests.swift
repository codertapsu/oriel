import CoreGraphics
@testable import Editor
import Foundation
import ImageIO
import OrielCore
import Testing

/// The background tool's model (PLAN §17): presets, the canvas's aspect and alignment, inset, window frame, the
/// exact pixel sizes of social presets, and the gradient geometry. Pure layout; rendering is checked in
/// `BackgroundRenderingTests`.
@MainActor
struct BackgroundLayoutTests {
    /// 200×150 pt at 2×.
    private func document() throws -> EditorDocument {
        try TestImages.document(width: 400, height: 300, scale: 2)
    }

    @Test(arguments: BackgroundPreset.allCases)
    func everyPresetPadsTheImageAndKeepsItsCard(_ preset: BackgroundPreset) throws {
        var document = try document()
        document = EditorDocument(base: document.base, preset: preset)
        let layout = CanvasLayout(document: document)
        guard let style = preset.style else {
            #expect(document.background == nil && document.canvasPadding == nil)
            #expect(layout.canvasSize == CGSize(width: 200, height: 150))
            return
        }
        let padding = BackgroundPreset.defaultPadding(for: CGSize(width: 200, height: 150))
        #expect(padding == 24)
        #expect(layout.canvasSize == CGSize(width: 248, height: 198))
        #expect(layout.cardRect == CGRect(x: 24, y: 24, width: 200, height: 150))
        #expect(layout.imageRect == layout.cardRect)
        #expect(style.isOpaque)
        #expect(!preset.title.isEmpty)
        if style.fill == .gradient || style.fill == .radial {
            #expect(style.colors.count >= 2)
        }
    }

    @Test(arguments: [
        (CanvasAspect.ratio(width: 16, height: 9), CGSize(width: 100, height: 100), CGSize(width: 100 * 16.0 / 9, height: 100)),
        (.ratio(width: 16, height: 9), CGSize(width: 400, height: 100), CGSize(width: 400, height: 225)),
        (.ratio(width: 1, height: 1), CGSize(width: 300, height: 120), CGSize(width: 300, height: 300)),
        (.ratio(width: 9, height: 16), CGSize(width: 90, height: 100), CGSize(width: 90, height: 160)),
        (.ratio(width: 4, height: 5), CGSize(width: 400, height: 100), CGSize(width: 400, height: 500)),
        (.pixels(width: 1200, height: 627), CGSize(width: 600, height: 600), CGSize(width: 600 * 1200.0 / 627, height: 600)),
        (.auto, CGSize(width: 123, height: 45), CGSize(width: 123, height: 45)),
    ])
    func anAspectGrowsOneSideOnly(_ aspect: CanvasAspect, _ size: CGSize, _ expected: CGSize) {
        let fitted = aspect.fitting(size)
        #expect(abs(fitted.width - expected.width) < 0.0001 && abs(fitted.height - expected.height) < 0.0001)
        #expect(fitted.width >= size.width - 0.0001 && fitted.height >= size.height - 0.0001)
    }

    @Test(arguments: AspectPreset.allCases)
    func everyAspectPresetHasItsShapeAndFindsItselfAgain(_ preset: AspectPreset) throws {
        guard let aspect = preset.aspect else {
            #expect(preset == .custom)
            #expect(AspectPreset.matching(.pixels(width: 999, height: 333)) == .custom)
            return
        }
        #expect(AspectPreset.matching(aspect) == preset)
        var document = try document()
        document.canvasPadding = Padding(all: 30)
        document.background = BackgroundStyle(fill: .solid, colors: [.white], aspect: aspect)
        let layout = CanvasLayout(document: document)
        if let ratio = aspect.ratio {
            #expect(abs(layout.canvasSize.width / layout.canvasSize.height - ratio) < 0.0001)
        } else {
            #expect(layout.canvasSize == CGSize(width: 260, height: 210))
        }
        // The image and its padding always fit.
        #expect(layout.cardRect.minX >= 30 - 0.0001 && layout.cardRect.minY >= 30 - 0.0001)
        #expect(layout.canvasSize.width - layout.cardRect.maxX >= 30 - 0.0001)
        #expect(layout.canvasSize.height - layout.cardRect.maxY >= 30 - 0.0001)
    }

    @Test(arguments: CanvasAlignment.allCases)
    func alignmentPlacesTheCardInTheSpareRoom(_ alignment: CanvasAlignment) throws {
        var document = try document()
        document.canvasPadding = Padding(all: 10)
        // 220×170 grown to a square: 50 points spare, all of it vertical.
        document.background = BackgroundStyle(fill: .none, aspect: .ratio(width: 1, height: 1), alignment: alignment)
        let layout = CanvasLayout(document: document)
        #expect(layout.canvasSize == CGSize(width: 220, height: 220))
        #expect(layout.cardRect.minX == 10)
        #expect(layout.cardRect.minY == 10 + 50 * alignment.vertical)
        // And the horizontal share, with a wide canvas.
        document.background = BackgroundStyle(fill: .none, aspect: .ratio(width: 2, height: 1), alignment: alignment)
        let wide = CanvasLayout(document: document)
        #expect(wide.canvasSize == CGSize(width: 340, height: 170))
        #expect(wide.cardRect.minX == 10 + 120 * alignment.horizontal)
        #expect(!alignment.title.isEmpty)
    }

    @Test func insetAndWindowFrameGrowTheCardAroundTheImage() throws {
        var document = try document()
        document.canvasPadding = Padding(all: 20)
        document.background = BackgroundStyle(fill: .solid, colors: [.white], inset: 12, windowFrame: .light)
        let layout = CanvasLayout(document: document)
        #expect(layout.cardRect == CGRect(x: 20, y: 20, width: 224, height: 202))
        #expect(layout.imageRect == CGRect(x: 32, y: 20 + 28 + 12, width: 200, height: 150))
        #expect(layout.canvasSize == CGSize(width: 264, height: 242))
        // An image-space point lands in the image rect.
        #expect(layout.canvasPoint(fromImage: CGPoint(x: 0, y: 0)) == CGPoint(x: 32, y: 60))
        // The crop moves which part of the image fills that rect, not where it is.
        document.crop = CGRect(x: 50, y: 40, width: 100, height: 80)
        let cropped = CanvasLayout(document: document)
        #expect(cropped.imageRect.size == CGSize(width: 100, height: 80))
        #expect(cropped.canvasPoint(fromImage: CGPoint(x: 50, y: 40)) == cropped.imageRect.origin)
    }

    @Test(arguments: [
        (400, 300, CGFloat(2)), (2880, 1800, 2), (1000, 200, 1), (64, 900, 1),
    ])
    func socialPresetsExportAtExactlyTheirPixelSize(_ width: Int, _ height: Int, _ scale: CGFloat) throws {
        let base = try #require(TestImages.halves(width: width, height: height))
        for preset in [AspectPreset.twitter, .linkedIn, .instagram, .instagramPortrait] {
            let size = try #require(preset.aspect?.pixelSize)
            var document = EditorDocument(base: ImageRef(image: base, scale: scale), preset: .ocean)
            document.background?.aspect = try #require(preset.aspect)
            let image = try #require(EditorExporter.image(document))
            #expect(image.width == size.width && image.height == size.height, "\(preset) on \(width)×\(height)@\(scale)")
            #expect(EditorExporter.dpiScale(of: document) == 1)
            let session = EditorSession(document: document)
            #expect(session.outputPixelSize == CGSize(width: size.width, height: size.height))
        }
    }

    @Test func aFixedSizeExportsAsAPNGOfThatSize() throws {
        var document = try document()
        document.background = BackgroundStyle(fill: .radial, colors: [.white, .black], aspect: .pixels(width: 1080, height: 1350))
        document.canvasPadding = Padding(all: 40)
        let data = try #require(EditorExporter.data(for: document, format: .png))
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 1080 && image.height == 1350)
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect((properties[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue == 72)
    }

    @Test func linearGradientsReachEveryCorner() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let horizontal = GradientGeometry.linearEndpoints(angle: 0, in: rect)
        #expect(horizontal.start == CGPoint(x: 0, y: 50) && horizontal.end == CGPoint(x: 200, y: 50))
        let vertical = GradientGeometry.linearEndpoints(angle: 90, in: rect)
        #expect(abs(vertical.start.y) < 0.0001 && abs(vertical.end.y - 100) < 0.0001)
        let diagonal = GradientGeometry.linearEndpoints(angle: 45, in: rect)
        // Every corner projects onto the gradient's span, so none falls outside the colours.
        let direction = CGVector(dx: diagonal.end.x - diagonal.start.x, dy: diagonal.end.y - diagonal.start.y)
        let length = direction.dx * direction.dx + direction.dy * direction.dy
        for corner in [CGPoint(x: 0, y: 0), CGPoint(x: 200, y: 0), CGPoint(x: 0, y: 100), CGPoint(x: 200, y: 100)] {
            let along = ((corner.x - diagonal.start.x) * direction.dx + (corner.y - diagonal.start.y) * direction.dy) / length
            #expect(along >= -0.0001 && along <= 1.0001)
        }
    }

    @Test func radialGradientsRunFromTheCentreToTheCorners() {
        let radial = GradientGeometry.radial(in: CGRect(x: 0, y: 0, width: 300, height: 400))
        #expect(radial.center == CGPoint(x: 150, y: 200))
        #expect(radial.radius == 250)
        let colors = [RGBAColor.black, .white, .red]
        func close(_ fraction: Double, _ expected: RGBAColor) -> Bool {
            guard let color = GradientGeometry.color(at: fraction, through: colors) else { return false }
            return abs(color.red - expected.red) < 0.0001 && abs(color.green - expected.green) < 0.0001
                && abs(color.blue - expected.blue) < 0.0001 && abs(color.alpha - expected.alpha) < 0.0001
        }
        #expect(close(0, .black))
        #expect(close(0.5, .white))
        #expect(close(1, .red))
        #expect(close(0.25, RGBAColor(red: 0.5, green: 0.5, blue: 0.5)))
        #expect(close(2, .red))
        #expect(GradientGeometry.color(at: 0.3, through: []) == nil)
    }

    @Test func theAutomaticShadowFollowsThePaddingAsVersionOneDrewIt() {
        let narrow = ShadowStyle.automatic(padding: Padding(all: 5))
        #expect(narrow.radius == 4 && narrow.opacity == 0.38)
        let usual = ShadowStyle.automatic(padding: Padding(all: 40))
        #expect(usual.radius == 16 && abs(usual.offset.height - 5.6) < 0.0001)
        #expect(ShadowStyle.automatic(padding: Padding(all: 200)).radius == 28)
        let clamped = ShadowStyle(radius: 500, opacity: 3, offset: .zero)
        #expect(clamped.radius == ShadowStyle.radiusRange.upperBound && clamped.opacity == 1)
    }

    @Test func theDesktopPictureIsReadOnlyFromFoldersThatNeedNoPermission() throws {
        let home = URL(fileURLWithPath: "/Users/someone", isDirectory: true)
        let allowed = [
            "/System/Library/Desktop Pictures/Sequoia.heic",
            "/Library/Desktop Pictures/Company.jpg",
            "/Users/someone/Pictures/Wallpapers/lake.png",
        ]
        let refused = [
            "/Users/someone/Desktop/wall.png",
            "/Users/someone/Documents/wall.png",
            "/Users/someone/Downloads/wall.png",
            "/Users/someone/Library/Mobile Documents/com~apple~CloudDocs/wall.png",
            "/Users/someone/Library/Containers/com.apple.wallpaper.agent/Data/wall.png",
            "/Users/someone/Pictures/Photos Library.photoslibrary/originals/A/wall.heic",
            "/Users/someone/Pictures/../Desktop/wall.png",
            "/Volumes/External/wall.png",
            "/Users/someoneelse/Pictures/wall.png",
        ]
        for path in allowed {
            #expect(DesktopPicture.isReadableWithoutPrompt(URL(fileURLWithPath: path), home: home), "\(path)")
        }
        for path in refused {
            #expect(!DesktopPicture.isReadableWithoutPrompt(URL(fileURLWithPath: path), home: home), "\(path)")
        }
        #expect(try !DesktopPicture.isReadableWithoutPrompt(#require(URL(string: "https://example.com/wall.png")), home: home))
        for failure in [DesktopPicture.Failure.unavailable, .protected, .unreadable] {
            #expect(failure.message.hasSuffix("instead."))
        }
    }
}
