import AppKit
import CoreGraphics
@testable import Editor
import Foundation
import Testing

/// The one renderer, checked structurally at 1× and 2× (PLAN §13.4, §14.4): references are computed in the
/// test from the synthetic base image, never stored.
@MainActor
struct RendererTests {
    private let left = RGBA8(red: 60, green: 90, blue: 140)
    private let right = RGBA8(red: 220, green: 200, blue: 160)
    private let green = RGBAColor(red: 0, green: 1, blue: 0)

    private func render(_ document: EditorDocument, scale: CGFloat, options: RenderOptions = RenderOptions()) throws -> PixelBuffer {
        let image = try #require(EditorRenderer.makeImage(document, scale: scale, options: options))
        return try PixelBuffer(image)
    }

    /// 100×60 pt at 2× (200×120 px): left half `left`, right half `right`.
    private func baseDocument() throws -> EditorDocument {
        try TestImages.document(width: 200, height: 120, scale: 2)
    }

    @Test(arguments: [CGFloat(1), 2, 3])
    func rendersAtExactPixelSizes(_ scale: CGFloat) throws {
        let pixels = try render(baseDocument(), scale: scale)
        #expect(pixels.width == Int(100 * scale) && pixels.height == Int(60 * scale))
    }

    @Test func pixelsWithoutAnnotationsAreTheBaseImageExactlyAtItsOwnScale() throws {
        var document = try baseDocument()
        document.items = [.rect(Box(rect: CGRect(x: 60, y: 10, width: 30, height: 20), color: green, width: 4))]
        let rendered = try render(document, scale: 2)
        let base = try PixelBuffer(document.base.image)
        let annotated = CGRect(x: 56, y: 6, width: 38, height: 28)
        var mismatches = 0
        for y in 0 ..< base.height {
            for x in 0 ..< base.width where !annotated.contains(CGPoint(x: CGFloat(x) / 2, y: CGFloat(y) / 2)) {
                if rendered.pixel(x, y) != base.pixel(x, y) {
                    mismatches += 1
                }
            }
        }
        #expect(mismatches == 0)
    }

    @Test(arguments: [CGFloat(1), 2])
    func annotationsLandInTheSamePlaceAtEveryScale(_ scale: CGFloat) throws {
        var document = try baseDocument()
        document.items = [
            .rect(Box(rect: CGRect(x: 10, y: 10, width: 30, height: 20), color: green, width: 4)),
            .line(Line(start: CGPoint(x: 60, y: 50), end: CGPoint(x: 95, y: 50), color: green, width: 4)),
        ]
        let pixels = try render(document, scale: scale)
        let greenPixel = RGBA8(red: 0, green: 255, blue: 0)
        #expect(pixels.pixel(at: CGPoint(x: 10.2, y: 20), scale: scale).distance(to: greenPixel) <= 3)
        #expect(pixels.pixel(at: CGPoint(x: 25, y: 30.2), scale: scale).distance(to: greenPixel) <= 3)
        #expect(pixels.pixel(at: CGPoint(x: 80, y: 50.2), scale: scale).distance(to: greenPixel) <= 3)
        #expect(pixels.pixel(at: CGPoint(x: 25, y: 20), scale: scale).distance(to: left) <= 1)
        #expect(pixels.pixel(at: CGPoint(x: 80, y: 30), scale: scale).distance(to: right) <= 1)
    }

    @Test func aTwoXRenderAveragedDownMatchesTheOneXRender() throws {
        var document = try baseDocument()
        document.items = [
            .arrow(Arrow(start: CGPoint(x: 8, y: 50), end: CGPoint(x: 45, y: 12), color: .red, width: 3)),
            .ellipse(Box(rect: CGRect(x: 55, y: 8, width: 36, height: 24), color: .yellow, width: 3)),
            .highlighter(FreehandPath(
                points: [CGPoint(x: 55, y: 45), CGPoint(x: 70, y: 40), CGPoint(x: 92, y: 48)],
                color: .yellow,
                width: 10
            )),
            .counter(Counter(center: CGPoint(x: 30, y: 40), number: 7, color: .blue, radius: 9)),
        ]
        let one = try render(document, scale: 1)
        let averaged = try render(document, scale: 2).downsampled(by: 2)
        let distances = zip(one.allPixels, averaged).map { $0.distance(to: $1) }
        let mean = Double(distances.reduce(0, +)) / Double(distances.count)
        let outliers = distances.filter { $0 > 48 }.count
        #expect(mean < 4, "mean channel difference \(mean)")
        #expect(Double(outliers) / Double(distances.count) < 0.03, "\(outliers) of \(distances.count) pixels differ a lot")
    }

    @Test func renderingIsDeterministic() throws {
        var document = try EditorDocument(base: ImageRef(image: #require(TestImages.noise(width: 160, height: 100)), scale: 2))
        document.background = BackgroundPreset.sunset.style
        document.canvasPadding = Padding(all: 16)
        document.items = [
            .blur(Region(rect: CGRect(x: 5, y: 5, width: 30, height: 20), amount: 6)),
            .pixelate(Region(rect: CGRect(x: 40, y: 5, width: 30, height: 20), amount: 6)),
            .spotlight(Region(rect: CGRect(x: 10, y: 30, width: 20, height: 15), amount: 0)),
            .text(TextBox(origin: CGPoint(x: 40, y: 30), text: "Same", color: .white, fontSize: 12)),
        ]
        let effects = EffectCache()
        let first = try render(document, scale: 2)
        let second = try PixelBuffer(#require(EditorRenderer.makeImage(document, scale: 2, effects: effects)))
        let cached = try PixelBuffer(#require(EditorRenderer.makeImage(document, scale: 2, effects: effects)))
        #expect(first.isIdentical(to: second))
        #expect(second.isIdentical(to: cached))
        #expect(effects.count >= 3)
    }

    @Test func blurSmoothsItsRegionAndNothingElse() throws {
        let noise = try #require(TestImages.noise(width: 200, height: 120))
        var document = EditorDocument(base: ImageRef(image: noise, scale: 2))
        document.items = [.blur(Region(rect: CGRect(x: 10, y: 10, width: 40, height: 30), amount: 4))]
        let rendered = try render(document, scale: 2)
        let original = try PixelBuffer(noise)
        let inside = CGRect(x: 24, y: 24, width: 72, height: 52)
        #expect(rendered.statistics(in: inside).variance < original.statistics(in: inside).variance / 10)
        for y in stride(from: 0, to: 120, by: 7) {
            for x in stride(from: 110, to: 200, by: 7) {
                #expect(rendered.pixel(x, y) == original.pixel(x, y))
            }
        }
    }

    /// Core Image blurs in linear light (so blurred noise reads brighter in sRGB), but a flat area must keep its
    /// colour: blurring a toolbar or a window background must not tint it.
    @Test func blurKeepsTheColourOfFlatAreas() throws {
        var document = try baseDocument()
        // A 4 pt blur reaches 12 pt; the region ends 28 pt before the colour boundary at x = 50 pt.
        document.items = [.blur(Region(rect: CGRect(x: 2, y: 5, width: 20, height: 50), amount: 4))]
        let rendered = try render(document, scale: 2)
        for y in stride(from: 12, to: 108, by: 5) {
            for x in stride(from: 6, to: 44, by: 3) {
                #expect(rendered.pixel(x, y).distance(to: left) <= 2, "pixel \(x), \(y)")
            }
        }
    }

    @Test func pixelateFillsTheRegionWithFlatBlocks() throws {
        let noise = try #require(TestImages.noise(width: 200, height: 120))
        var document = EditorDocument(base: ImageRef(image: noise, scale: 2))
        document.items = [.pixelate(Region(rect: CGRect(x: 0, y: 0, width: 40, height: 40), amount: 10))]
        let rendered = try render(document, scale: 2)
        // Blocks are 20 px; this 6 px window lies inside one block whether blocks start or centre on the corner.
        let reference = rendered.pixel(22, 22)
        for y in 22 ..< 28 {
            for x in 22 ..< 28 {
                #expect(rendered.pixel(x, y).distance(to: reference) <= 2)
            }
        }
        let original = try PixelBuffer(noise)
        let region = CGRect(x: 0, y: 0, width: 80, height: 80)
        #expect(rendered.statistics(in: region).variance < original.statistics(in: region).variance)
        #expect(rendered.pixel(150, 100) == original.pixel(150, 100))
    }

    @Test func spotlightDimsAllButItsAreaAndAnnotationsStayBright() throws {
        var document = try baseDocument()
        document.items = [
            .counter(Counter(center: CGPoint(x: 80, y: 30), number: 1, color: green, radius: 10)),
            .spotlight(Region(rect: CGRect(x: 10, y: 10, width: 30, height: 30), amount: 0)),
        ]
        let pixels = try render(document, scale: 2)
        #expect(pixels.pixel(at: CGPoint(x: 25, y: 25), scale: 2) == left)
        let dimmed = pixels.pixel(at: CGPoint(x: 60, y: 50), scale: 2)
        #expect(Int(dimmed.red) < Int(right.red) * 6 / 10 && Int(dimmed.green) < Int(right.green) * 6 / 10)
        // The step was drawn before the spotlight in z-order, yet it is not dimmed.
        #expect(pixels.pixel(at: CGPoint(x: 73, y: 30), scale: 2).distance(to: RGBA8(red: 0, green: 255, blue: 0)) <= 3)
    }

    @Test func backgroundPaddingCornerRadiusAndShadowSurroundTheImage() throws {
        var document = try baseDocument()
        document.background = BackgroundPreset.paper.style
        document.canvasPadding = Padding(all: 24)
        let pixels = try render(document, scale: 2)
        #expect(pixels.width == 296 && pixels.height == 216)
        let paper = RGBA8(red: 242, green: 242, blue: 247)
        #expect(pixels.pixel(1, 1).distance(to: paper) <= 2)
        #expect(pixels.pixel(at: CGPoint(x: 24 + 25, y: 24 + 30), scale: 2) == left)
        #expect(pixels.pixel(at: CGPoint(x: 24 + 75, y: 24 + 30), scale: 2) == right)
        // The rounded corner cuts the image's corner pixel off.
        #expect(pixels.pixel(at: CGPoint(x: 24.5, y: 24.5), scale: 2).distance(to: left) > 40)
        // Below the card the shadow darkens the paper; far from it, the paper is untouched.
        let shadow = pixels.pixel(at: CGPoint(x: 74, y: 24 + 60 + 4), scale: 2)
        #expect(Int(shadow.red) < 228)
        #expect(pixels.pixel(at: CGPoint(x: 147, y: 107), scale: 2).distance(to: paper) <= 2)
    }

    @Test func cropShowsOnlyTheCroppedPartAndTheCropToolShowsEverything() throws {
        var document = try baseDocument()
        document.crop = CGRect(x: 50, y: 0, width: 50, height: 60)
        let cropped = try render(document, scale: 2)
        #expect(cropped.width == 100 && cropped.height == 120)
        #expect(Set(cropped.allPixels.map { $0.distance(to: right) <= 1 }) == [true])
        let whole = try render(document, scale: 2, options: RenderOptions(showsUncroppedImage: true))
        #expect(whole.width == 200 && whole.pixel(10, 10) == left)
    }

    @Test func labelsDrawUprightInsideTheirFrame() throws {
        let white = try #require(TestImages.make(width: 240, height: 160) { _, _ in RGBA8(red: 255, green: 255, blue: 255) })
        var document = EditorDocument(base: ImageRef(image: white, scale: 2))
        let label = TextBox(origin: CGPoint(x: 10, y: 10), text: "T", color: .black, fontSize: 60)
        document.items = [.text(label)]
        let pixels = try render(document, scale: 2)
        var inkRows: [Int: Int] = [:]
        for y in 0 ..< pixels.height {
            for x in 0 ..< pixels.width where pixels.pixel(x, y).red < 128 {
                let point = CGPoint(x: CGFloat(x) / 2, y: CGFloat(y) / 2)
                #expect(label.frame.insetBy(dx: -1, dy: -1).contains(point), "ink outside the label at \(point)")
                inkRows[y, default: 0] += 1
            }
        }
        let rows = inkRows.keys.sorted()
        let top = try #require(rows.first), bottom = try #require(rows.last)
        let quarter = (bottom - top) / 4
        let topInk = rows.filter { $0 <= top + quarter }.reduce(0) { $0 + (inkRows[$1] ?? 0) }
        let bottomInk = rows.filter { $0 >= bottom - quarter }.reduce(0) { $0 + (inkRows[$1] ?? 0) }
        // A T is wide at the top and narrow at the bottom; upside-down text would be the other way round.
        #expect(topInk > bottomInk * 2)
    }

    @Test func jpegMatteFlattensTransparencyOntoWhite() throws {
        var document = try baseDocument()
        document.canvasPadding = Padding(all: 10)
        let transparent = try render(document, scale: 1)
        #expect(transparent.pixel(2, 2).alpha == 0)
        let matted = try render(document, scale: 1, options: RenderOptions(matte: .white))
        #expect(matted.pixel(2, 2) == RGBA8(red: 255, green: 255, blue: 255))
    }

    @Test func theCanvasViewDrawsWhatTheExporterRenders() throws {
        var document = try baseDocument()
        document.background = BackgroundPreset.ocean.style
        document.canvasPadding = Padding(all: 12)
        document.items = [
            .arrow(Arrow(start: CGPoint(x: 10, y: 50), end: CGPoint(x: 60, y: 15), color: .red, width: 3)),
            .counter(Counter(center: CGPoint(x: 80, y: 40), number: 2, color: .blue, radius: 9)),
            .text(TextBox(origin: CGPoint(x: 8, y: 6), text: "View", color: .white, fontSize: 11)),
        ]
        let session = EditorSession(document: document)
        let view = EditorCanvasView(session: session)
        view.frame = CGRect(origin: .zero, size: session.layout.canvasSize)
        let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        let drawn = try PixelBuffer(#require(rep.cgImage))
        let scale = CGFloat(drawn.width) / session.layout.canvasSize.width
        let rendered = try render(document, scale: scale)
        #expect(drawn.width == rendered.width && drawn.height == rendered.height)
        let distances = zip(drawn.allPixels, rendered.allPixels).map { $0.distance(to: $1) }
        let mean = Double(distances.reduce(0, +)) / Double(max(distances.count, 1))
        #expect(mean < 3, "mean channel difference \(mean)")
        #expect(Double(distances.filter { $0 > 24 }.count) / Double(max(distances.count, 1)) < 0.01)
    }
}
