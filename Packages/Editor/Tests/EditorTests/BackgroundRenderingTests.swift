import CoreGraphics
@testable import Editor
import Foundation
import OrielCore
import Testing

/// What the background tool draws (PLAN §17): radial gradients, pictures, the inset in the image's edge colour, the
/// window frame, the shadow's settings; and its commands, saved presets and live previews.
@MainActor
struct BackgroundRenderingTests {
    private let left = RGBA8(red: 60, green: 90, blue: 140)

    /// 100×60 pt at 2×, the left half blue-grey, the right half sand.
    private func document() throws -> EditorDocument {
        try TestImages.document(width: 200, height: 120, scale: 2)
    }

    private func render(_ document: EditorDocument, scale: CGFloat = 2) throws -> PixelBuffer {
        try PixelBuffer(#require(EditorRenderer.makeImage(document, scale: scale)))
    }

    @Test func aRadialGradientIsItsFirstColourInTheMiddleAndItsLastAtTheCorners() throws {
        var document = try document()
        document.canvasPadding = Padding(all: 60)
        document.background = BackgroundStyle(fill: .radial, colors: [.white, .black], shadow: false, cornerRadius: 0)
        let pixels = try render(document, scale: 1)
        // The image covers the middle; just above it, the gradient is still nearly white, the corner is black.
        let nearMiddle = pixels.pixel(110, 55)
        #expect(nearMiddle.red > 160)
        #expect(pixels.pixel(0, 0).distance(to: RGBA8(red: 0, green: 0, blue: 0)) <= 3)
        #expect(pixels.pixel(80, 90).distance(to: left) <= 1)
    }

    @Test func theInsetIsFilledWithTheImagesEdgeColour() throws {
        // A frame of sand around a dark middle: the edge colour is the sand.
        let image = try #require(TestImages.make(width: 200, height: 120) { x, y in
            x < 10 || y < 10 || x >= 190 || y >= 110 ? RGBA8(red: 220, green: 200, blue: 160) : RGBA8(red: 20, green: 20, blue: 20)
        })
        var document = EditorDocument(base: ImageRef(image: image, scale: 2))
        document.canvasPadding = Padding(all: 20)
        document.background = BackgroundStyle(fill: .solid, colors: [.blue], shadow: false, cornerRadius: 0, inset: 10)
        let pixels = try render(document)
        // 20 pt padding (blue), then 10 pt inset (sand), then the image.
        #expect(pixels.pixel(at: CGPoint(x: 10, y: 60), scale: 2).distance(to: RGBA8(red: 0, green: 122, blue: 255)) <= 2)
        #expect(pixels.pixel(at: CGPoint(x: 25, y: 60), scale: 2).distance(to: RGBA8(red: 220, green: 200, blue: 160)) <= 3)
        #expect(pixels.pixel(at: CGPoint(x: 80, y: 60), scale: 2).distance(to: RGBA8(red: 20, green: 20, blue: 20)) <= 2)
        #expect(EdgeColor.estimate(image, in: PixelRect(x: 0, y: 0, width: 200, height: 120)) == RGBAColor(
            red: 220.0 / 255, green: 200.0 / 255, blue: 160.0 / 255
        ))
    }

    @Test func theWindowFrameDrawsATitleBarWithItsLights() throws {
        var document = try document()
        document.canvasPadding = Padding(all: 10)
        document.background = BackgroundStyle(fill: .solid, colors: [.white], shadow: false, cornerRadius: 0, windowFrame: .dark)
        let pixels = try render(document)
        let (bar, _) = WindowFramePainter.colors(for: .dark)
        // The bar, between the lights and the right edge.
        let barPixel = pixels.pixel(at: CGPoint(x: 90, y: 10 + 14), scale: 2)
        #expect(barPixel.distance(to: RGBA8(red: UInt8(bar.red * 255), green: UInt8(bar.green * 255), blue: UInt8(bar.blue * 255))) <= 2)
        // The close light, red, 12 pt from the card's left edge.
        let close = pixels.pixel(at: CGPoint(x: 10 + 12 + 6, y: 10 + 14), scale: 2)
        #expect(close.red > 230 && close.green < 120 && close.blue < 120)
        // The image starts below the bar.
        #expect(pixels.pixel(at: CGPoint(x: 30, y: 10 + 28 + 5), scale: 2) == left)
    }

    @Test func aPictureCoversTheCanvasAndCanBeBlurred() throws {
        let picture = try #require(TestImages.make(width: 80, height: 40) { x, _ in
            x < 40 ? RGBA8(red: 255, green: 0, blue: 0) : RGBA8(red: 0, green: 0, blue: 255)
        })
        var document = try document()
        document.canvasPadding = Padding(all: 30)
        document.background = BackgroundStyle(
            fill: .image, image: BackgroundImage(asset: ImageAsset(image: picture), source: .file), shadow: false, cornerRadius: 0
        )
        let sharp = try render(document)
        // 160×120 canvas: the 2:1 picture covers it, cropped at the sides, red on the left, blue on the right.
        #expect(sharp.pixel(at: CGPoint(x: 5, y: 60), scale: 2).distance(to: RGBA8(red: 255, green: 0, blue: 0)) <= 2)
        #expect(sharp.pixel(at: CGPoint(x: 155, y: 60), scale: 2).distance(to: RGBA8(red: 0, green: 0, blue: 255)) <= 2)
        #expect(document.background?.isOpaque == true)
        document.background?.image?.blur = 20
        let blurred = try render(document)
        // Blurred, the halves mix near the middle but the far edges keep their colour.
        let middle = blurred.pixel(at: CGPoint(x: 80, y: 10), scale: 2)
        #expect(middle.red > 40 && middle.blue > 40)
        #expect(blurred.pixel(at: CGPoint(x: 2, y: 60), scale: 2).red > 200)
    }

    @Test func aPictureFillWithoutItsPixelsShowsAPlaceholder() throws {
        var document = try document()
        document.canvasPadding = Padding(all: 20)
        document.background = BackgroundStyle(fill: .image, shadow: false)
        let pixels = try render(document)
        let placeholder = BackgroundPainter.placeholder
        #expect(pixels.pixel(2, 2).distance(to: RGBA8(
            red: UInt8((placeholder.red * 255).rounded()), green: UInt8((placeholder.green * 255).rounded()),
            blue: UInt8((placeholder.blue * 255).rounded())
        )) <= 2)
    }

    @Test func theShadowFollowsItsSettings() throws {
        var document = try document()
        document.canvasPadding = Padding(all: 40)
        document.background = BackgroundStyle(
            fill: .solid,
            colors: [.white],
            shadowStyle: ShadowStyle(radius: 6, opacity: 0, offset: .zero)
        )
        let none = try render(document)
        #expect(none.pixel(at: CGPoint(x: 90, y: 40 + 60 + 4), scale: 2) == RGBA8(red: 255, green: 255, blue: 255))
        document.background?.shadowStyle = ShadowStyle(radius: 6, opacity: 1, offset: CGSize(width: 0, height: 12))
        let dark = try render(document)
        // Below the card the shadow, offset down, darkens the white; above it there is next to none.
        #expect(dark.pixel(at: CGPoint(x: 90, y: 40 + 60 + 8), scale: 2).red < 150)
        #expect(dark.pixel(at: CGPoint(x: 90, y: 40 - 8), scale: 2).red > 240)
    }

    @Test func toningDownWashesTheImageOut() throws {
        var document = try document()
        let before = try render(document).pixel(20, 20)
        document.tone = 1
        let after = try render(document).pixel(20, 20)
        // Greyer (the channels closer together) and lighter.
        let spread = { (pixel: RGBA8) in Int(max(pixel.red, pixel.green, pixel.blue)) - Int(min(pixel.red, pixel.green, pixel.blue)) }
        #expect(spread(after) < spread(before) / 2)
        #expect(after.red > before.red && after.green > before.green)
    }

    @Test func backgroundCommandsAreOneUndoStepEach() throws {
        let session = try EditorSession(document: document())
        // Without a background, an option creates a transparent one with the default padding.
        session.setAspect(.ratio(width: 16, height: 9))
        #expect(session.document.background?.fill == BackgroundStyle.Fill.none)
        #expect(session.document.canvasPadding == Padding(all: 24))
        session.applyBackground(.aurora)
        #expect(session.document.background?.fill == .radial)
        // A preset changes the fill only.
        #expect(session.document.background?.aspect == .ratio(width: 16, height: 9))
        for value in stride(from: 2.0, through: 20, by: 2) {
            session.setInset(CGFloat(value))
        }
        session.setWindowFrame(.light)
        session.setAlignment(.bottomLeading)
        session.setFill(.solid)
        session.setFillColor(.green, at: 0)
        session.setFill(.gradient)
        #expect((session.document.background?.colors.count ?? 0) >= 2)
        session.setShadowStyle(ShadowStyle(radius: 30, opacity: 0.2, offset: .zero), coalescing: "shadowBlur")
        session.setShadowStyle(ShadowStyle(radius: 40, opacity: 0.2, offset: .zero), coalescing: "shadowBlur")
        let style = try #require(session.document.background)
        #expect(style.inset == 20 && style.windowFrame == .light && style.alignment == .bottomLeading)
        #expect(style.colors.first == .green && style.shadowStyle?.radius == 40)
        // Picture without pixels: refused, nothing changes.
        session.setFill(.image)
        #expect(session.document.background?.fill == .gradient)
        // Aspect, preset, inset drag, frame, alignment, solid, colour, gradient, shadow drag: nine steps.
        for _ in 0 ..< 9 {
            session.undo()
        }
        #expect(session.document.background == nil && session.document.canvasPadding == nil)
        #expect(!session.canUndo)
    }

    @Test func aChosenPictureBecomesTheFillAndKeepsItsBlur() throws {
        let session = try EditorSession(document: document())
        let picture = try ImageAsset(image: #require(TestImages.noise(width: 30, height: 20)))
        session.setBackgroundImage(picture, source: .file)
        session.setBackgroundBlur(12)
        let other = try ImageAsset(image: #require(TestImages.noise(width: 10, height: 10)))
        session.setBackgroundImage(other, source: .desktopPicture)
        let image = try #require(session.document.background?.image)
        #expect(session.document.background?.fill == .image)
        #expect(image.asset == other && image.source == .desktopPicture && image.blur == 12)
        #expect(session.document.assets == [other])
    }

    @Test func savedBackgroundsKeepTheirPictureAsAFileOfTheirOwn() async throws {
        let suiteName = "com.codertapsu.oriel.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "oriel-backgrounds-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = SettingsStore(defaults: defaults)
        let library = BackgroundLibrary(settings: settings, directory: directory)
        let picture = try ImageAsset(image: #require(TestImages.halves(width: 40, height: 20)))
        let style = BackgroundStyle(
            fill: .image,
            image: BackgroundImage(asset: picture, source: .file, blur: 4),
            inset: 6,
            windowFrame: .dark
        )
        await library.save(name: "  Launch  ", style: style, padding: 32)
        try await library.save(name: "", style: #require(BackgroundPreset.mint.style), padding: 20)
        #expect(library.presets.map(\.name) == ["Launch", "My Background"])
        #expect(settings[EditorSettings.savedBackgrounds] == library.presets)
        let saved = try #require(library.presets.first)
        guard case let .file(name, blur) = saved.picture else {
            Issue.record("the picture was not kept")
            return
        }
        #expect(blur == 4 && saved.style.image == nil)
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: name).path))
        // Applying loads the picture back; a fresh library reads the same list from the settings.
        let restored = try #require(await BackgroundLibrary(settings: settings, directory: directory).style(for: saved) { nil })
        #expect(restored.fill == .image && restored.inset == 6 && restored.windowFrame == .dark)
        #expect(restored.image?.asset.pixelSize == CGSize(width: 40, height: 20))
        library.delete(saved.id)
        #expect(library.presets.count == 1)
        // The desktop picture is read again when applied, so a preset made with it follows the desktop.
        let desktop = SavedBackground(name: "Desk", style: BackgroundStyle(fill: .image), padding: 10, picture: .desktopPicture(blur: 2))
        let fresh = try #require(TestImages.noise(width: 8, height: 8))
        let applied = try #require(await library.style(for: desktop) { fresh })
        #expect(applied.image?.source == .desktopPicture && applied.image?.blur == 2)
        #expect(await library.style(for: desktop) { nil } == nil)
    }

    @Test func previewTilesShowTheScreenshotOnEachBackgroundAndAreCached() throws {
        var document = try document()
        document.items = [.rect(Box(rect: CGRect(x: 10, y: 10, width: 40, height: 20), color: .red, width: 3))]
        let previews = BackgroundPreviews()
        let limit = CGSize(width: BackgroundPreviews.tileSize.width * 2, height: BackgroundPreviews.tileSize.height * 2)
        for preset in BackgroundPreset.allCases {
            let tile = try #require(previews.tile(for: document, style: preset.style, padding: 24))
            #expect(CGFloat(tile.width) <= limit.width + 1 && CGFloat(tile.height) <= limit.height + 1)
        }
        let first = previews.tile(for: document, style: BackgroundPreset.ocean.style, padding: 24)
        #expect(first === previews.tile(for: document, style: BackgroundPreset.ocean.style, padding: 24))
        // A new annotation makes new tiles.
        document.items.append(.counter(Counter(center: CGPoint(x: 80, y: 30), number: 1, color: .blue, radius: 10)))
        #expect(first !== previews.tile(for: document, style: BackgroundPreset.ocean.style, padding: 24))
    }
}
