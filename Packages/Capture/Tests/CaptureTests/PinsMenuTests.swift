@testable import Capture
import CoreGraphics
import OrielCore
import Testing

/// The status menu's Pinned submenu (PLAN §10.1).
@MainActor
struct PinsMenuTests {
    private func result(kind: CaptureKind = .area, appName: String? = nil, windowTitle: String? = nil) throws -> CaptureResult {
        try CaptureResult(
            image: TestImages.quadrants(width: 40, height: 30),
            kind: kind,
            rect: .zero,
            scale: 2,
            windowTitle: windowTitle,
            appName: appName
        )
    }

    @Test func titlesNameTheSourceThenTheTime() throws {
        #expect(try PinsMenu.title(for: result(appName: "Safari", windowTitle: "Start Page"), time: "14:02") == "Safari · 14:02")
        #expect(try PinsMenu.title(for: result(appName: "", windowTitle: "Notes"), time: "9:41") == "Notes · 9:41")
        #expect(try PinsMenu.title(for: result(kind: .scrolling), time: "9:41") == "Scrolling Capture · 9:41")
        #expect(try PinsMenu.title(for: result(kind: .imported), time: "9:41") == "Image · 9:41")
    }

    @Test func thumbnailsKeepTheirShape() {
        #expect(PinsMenu.fittedSize(of: CGSize(width: 400, height: 100)) == CGSize(width: 36, height: 9))
        #expect(PinsMenu.fittedSize(of: CGSize(width: 100, height: 400)) == CGSize(width: 5, height: 18))
        #expect(PinsMenu.fittedSize(of: CGSize(width: 1, height: 1000)) == CGSize(width: 1, height: 18))
        #expect(PinsMenu.fittedSize(of: .zero) == PinsMenu.thumbnailSize)
    }

    @Test func nothingPinnedMeansNoMenu() throws {
        #expect(PinsMenu.make(for: [], reveal: { _ in }, closeAll: {}) == nil)
        let menu = try #require(try PinsMenu.make(for: [result(appName: "Safari"), result()], reveal: { _ in }, closeAll: {}))
        #expect(menu.items.count == 4) // two pins, a separator, Close All Pins
        #expect(menu.items.last?.title == "Close All Pins")
    }
}
