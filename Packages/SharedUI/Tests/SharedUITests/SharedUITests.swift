import CoreGraphics
import Foundation
import ImageIO
import SharedUI
import Testing

@MainActor
struct SharedUITests {
    private func checkerboard(width: Int = 8, height: Int = 6) throws -> CGImage {
        let sRGB = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: sRGB,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        return try #require(context.makeImage())
    }

    @Test(arguments: ImageFile.Format.allCases)
    func imagesRoundTripThroughEveryFormat(_ format: ImageFile.Format) throws {
        let image = try checkerboard()
        let url = FileManager.default.temporaryDirectory.appending(path: "oriel-\(UUID().uuidString).\(format.fileExtension)")
        defer { try? FileManager.default.removeItem(at: url) }
        try ImageFile.write(image, to: url, format: format, scale: 2)
        let loaded = try #require(ImageFile.load(url))
        #expect(loaded.width == 8 && loaded.height == 6)
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect((properties[kCGImagePropertyDPIWidth] as? Double) == 144)
    }

    @Test func accessibilityOptionsDecideOnGlass() {
        #expect(AccessibilityDisplay(reduceTransparency: false, increaseContrast: false, reduceMotion: true).allowsGlass)
        #expect(!AccessibilityDisplay(reduceTransparency: true, increaseContrast: false, reduceMotion: false).allowsGlass)
        #expect(!AccessibilityDisplay(reduceTransparency: false, increaseContrast: true, reduceMotion: false).allowsGlass)
    }

    @Test func glassBackgroundSwitchesToOpaqueWithAnAccessibleBorder() {
        let view = Material.make(cornerRadius: 12)
        #expect(view.cornerRadius == 12)
        #expect(view.contentView.superview != nil)
        let solid = !AccessibilityDisplay.current.allowsGlass
        #expect((view.layer?.borderWidth ?? 0) == (solid ? 1 : 0))
    }

    @Test func floatingPanelsNeverTakeFocusByDefault() {
        let panel = FloatingPanel()
        #expect(!panel.canBecomeKey && !panel.canBecomeMain)
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
        panel.allowsKey = true
        #expect(panel.canBecomeKey)
    }
}
