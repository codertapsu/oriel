@testable import Capture
import CoreGraphics
import Testing

/// The dev Mac's layout: a 2× built-in display as primary, a 1× external above-right of it with a negative y, and a
/// 1× display to the left with a negative x.
struct CaptureGeometryTests {
    private let primary = DisplayFrame(id: 1, frame: CGRect(x: 0, y: 0, width: 1512, height: 982), scale: 2)
    private let external = DisplayFrame(id: 2, frame: CGRect(x: 1512, y: -458, width: 2560, height: 1440), scale: 1)
    private let left = DisplayFrame(id: 3, frame: CGRect(x: -1920, y: -98, width: 1920, height: 1080), scale: 1)

    private var displays: [DisplayFrame] {
        [primary, external, left]
    }

    @Test func selectionsBelongToTheDisplayThatShowsMostOfThem() {
        #expect(CaptureGeometry.display(for: CGRect(x: 1400, y: 0, width: 300, height: 100), among: displays) == external)
        #expect(CaptureGeometry.display(for: CGRect(x: -50, y: 10, width: 40, height: 40), among: displays) == left)
        #expect(CaptureGeometry.display(for: CGRect(x: 9000, y: 9000, width: 10, height: 10), among: displays) == nil)
        #expect(CaptureGeometry.display(containing: CGPoint(x: 1512, y: 0), among: displays) == external)
        #expect(CaptureGeometry.display(containing: CGPoint(x: -1, y: 0), among: displays) == left)
    }

    @Test(arguments: [
        // Area capture pixel dimensions = selection × scale (PLAN §13.3).
        (CGRect(x: 100, y: 100, width: 400, height: 300), CGRect(x: 200, y: 200, width: 800, height: 600)),
        // Half-point edges on a 2× display are whole pixels.
        (CGRect(x: 10.5, y: 0.5, width: 20, height: 10.5), CGRect(x: 21, y: 1, width: 40, height: 21)),
    ])
    func retinaSelectionsCropAtTwicePointSize(selection: CGRect, expected: CGRect) {
        #expect(CaptureGeometry.pixelRect(for: selection, on: primary) == expected)
    }

    @Test func externalAndNegativeOriginDisplaysCropRelativeToThemselves() {
        let onExternal = CaptureGeometry.pixelRect(for: CGRect(x: 1600, y: -400, width: 400, height: 300), on: external)
        #expect(onExternal == CGRect(x: 88, y: 58, width: 400, height: 300))
        let onLeft = CaptureGeometry.pixelRect(for: CGRect(x: -1900, y: -90, width: 100, height: 50), on: left)
        #expect(onLeft == CGRect(x: 20, y: 8, width: 100, height: 50))
        // Clipped to the display it is cropped from.
        let straddling = CaptureGeometry.pixelRect(for: CGRect(x: 1500, y: 0, width: 100, height: 10), on: primary)
        #expect(straddling == CGRect(x: 3000, y: 0, width: 24, height: 20))
    }

    @Test func allDisplaysComposeAtTheHighestScale() throws {
        let composite = try #require(CaptureGeometry.composite(of: displays))
        #expect(composite.bounds == CGRect(x: -1920, y: -458, width: 5992, height: 1440))
        #expect(composite.scale == 2)
        #expect(composite.pixelSize == CGSize(width: 11984, height: 2880))
        #expect(composite.placements == [
            CGRect(x: 3840, y: 916, width: 3024, height: 1964),
            CGRect(x: 6864, y: 0, width: 5120, height: 2880),
            CGRect(x: 0, y: 720, width: 3840, height: 2160),
        ])
        #expect(CaptureGeometry.composite(of: []) == nil)
    }

    @Test func alignmentSnapsToTheDisplaysPixelGrid() {
        #expect(CaptureGeometry.align(100.3, origin: 0, scale: 2) == 100.5)
        #expect(CaptureGeometry.align(100.3, origin: 0, scale: 1) == 100)
        let rect = CaptureGeometry.align(CGRect(x: 1600.4, y: -457.6, width: 10.2, height: 10.2), in: external.frame, scale: 1)
        #expect(rect == CGRect(x: 1600, y: -458, width: 11, height: 11))
    }

    @Test func shiftingKeepsSizeAndStaysInside() {
        let bounds = primary.frame
        #expect(CaptureGeometry.shiftInside(CGRect(x: -10, y: 970, width: 100, height: 50), bounds: bounds) == CGRect(
            x: 0,
            y: 932,
            width: 100,
            height: 50
        ))
        #expect(CaptureGeometry.shiftInside(CGRect(x: 0, y: 0, width: 4000, height: 10), bounds: bounds).width == 1512)
    }

    @Test func croppingCopiesExactlyThePixelsAsked() throws {
        let image = try TestImages.quadrants(width: 20, height: 20)
        let topRight = try #require(ImageCropping.crop(image, to: CGRect(x: 10, y: 0, width: 10, height: 10)))
        #expect(topRight.width == 10 && topRight.height == 10)
        #expect(try TestImages.hex(topRight, x: 5, y: 5) == "#0000FF")
        let bottom = try #require(ImageCropping.crop(image, to: CGRect(x: 0, y: 15, width: 20, height: 100)))
        #expect(bottom.height == 5)
        #expect(try TestImages.hex(bottom, x: 3, y: 2) == "#FF0000")
        #expect(ImageCropping.crop(image, to: CGRect(x: 30, y: 30, width: 5, height: 5)) == nil)
    }

    @Test func compositeDrawsEachDisplayInItsPlace() throws {
        let red = try TestImages.solid(width: 4, height: 4, red: 1, green: 0, blue: 0)
        let blue = try TestImages.solid(width: 2, height: 2, red: 0, green: 0, blue: 1)
        let layout = try #require(CaptureGeometry.composite(of: [
            DisplayFrame(id: 1, frame: CGRect(x: 0, y: 0, width: 2, height: 2), scale: 2),
            DisplayFrame(id: 2, frame: CGRect(x: 2, y: -2, width: 2, height: 2), scale: 1),
        ]))
        let image = try #require(ImageCropping.compose([red, blue], layout: layout))
        #expect(image.width == 8 && image.height == 8)
        #expect(try TestImages.hex(image, x: 1, y: 5) == "#FF0000")
        #expect(try TestImages.hex(image, x: 6, y: 1) == "#0000FF")
        let empty = try #require(PixelPatch.sample(image, x: 1, y: 1, size: 1))
        #expect(empty.pixels[3] == 0)
    }

    @Test func windowsAreHitFrontToBack() {
        let back = WindowTarget(id: 10, frame: CGRect(x: 0, y: 0, width: 500, height: 500), title: "Back", appName: "A", processID: 1)
        let front = WindowTarget(id: 11, frame: CGRect(x: 100, y: 100, width: 100, height: 100), title: "Front", appName: "B", processID: 2)
        let ordered = WindowTarget.sorted([back, front], byFrontToBack: [11, 99, 10])
        #expect(ordered.map(\.id) == [11, 10])
        #expect(WindowTarget.topmost(at: CGPoint(x: 150, y: 150), in: ordered)?.id == 11)
        #expect(WindowTarget.topmost(at: CGPoint(x: 50, y: 50), in: ordered)?.id == 10)
        #expect(WindowTarget.topmost(at: CGPoint(x: 900, y: 50), in: ordered) == nil)
    }

    @Test func previewsKeepTheirShape() {
        let bounds = CGRect(x: 0, y: 0, width: 248, height: 164)
        // A tall scrolling capture (scaled by 1/16) and a wide one (by 1/4), centred.
        let tall = CaptureGeometry.aspectFit(CGSize(width: 500, height: 2624), in: bounds)
        #expect(tall == CGRect(x: 108.375, y: 0, width: 31.25, height: 164))
        #expect(CaptureGeometry.aspectFit(CGSize(width: 992, height: 328), in: bounds) == CGRect(x: 0, y: 41, width: 248, height: 82))
        #expect(CaptureGeometry.aspectFit(.zero, in: bounds) == bounds)
    }

    /// On macOS 26 Oriel's status item is a window of its own; it stays in captures while its panels are left out.
    @Test func onlyTheStatusItemOfOrielsWindowsStaysInCaptures() {
        let level = Int(CGWindowLevelForKey(.statusWindow))
        let tops: Set<CGFloat> = [0, -458]
        #expect(ShareableContentCache.isStatusItem(layer: level, frame: CGRect(x: 1300, y: 0, width: 30, height: 33), menuBarTops: tops))
        #expect(ShareableContentCache.isStatusItem(layer: level, frame: CGRect(x: 3000, y: -458, width: 30, height: 24), menuBarTops: tops))
        // A Quick Access card or a toast at the same level, lower down.
        #expect(!ShareableContentCache.isStatusItem(
            layer: level,
            frame: CGRect(x: 1240, y: 700, width: 264, height: 214),
            menuBarTops: tops
        ))
        #expect(!ShareableContentCache.isStatusItem(layer: level, frame: CGRect(x: 600, y: 860, width: 120, height: 40), menuBarTops: tops))
        #expect(!ShareableContentCache.isStatusItem(layer: 3, frame: CGRect(x: 0, y: 0, width: 30, height: 30), menuBarTops: tops))
    }
}
