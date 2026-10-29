import AppKit
@testable import Capture
import CoreGraphics
import OrielCore
import Testing

/// The status menu's Pinned submenu and a pin's own commands (PLAN §10.1, §17).
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

    private func menu(_ entries: [PinsMenu.Entry]) -> NSMenu? {
        PinsMenu.make(for: entries, perform: { _, _ in }, stopClickThrough: {}, closeAll: {})
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
        #expect(menu([]) == nil)
        let pinned = try #require(try menu([
            PinsMenu.Entry(result: result(appName: "Safari"), state: PinState()),
            PinsMenu.Entry(result: result(), state: PinState()),
        ]))
        #expect(pinned.items.count == 4) // two pins, a separator, Close All Pins
        #expect(pinned.items.last?.title == "Close All Pins")
        #expect(pinned.items.first?.submenu?.items.first?.title == "Bring to Front")
    }

    @Test func aClickThroughPinCanAlwaysBeTurnedBack() throws {
        var through = PinState()
        through.isClickThrough = true
        through.setOpacity(0.6)
        let pinned = try #require(try menu([
            PinsMenu.Entry(result: result(appName: "Safari"), state: through),
            PinsMenu.Entry(result: result(appName: "Xcode"), state: PinState()),
        ]))
        #expect(pinned.items.map(\.title).suffix(2) == ["Stop Click-Through on All Pins", "Close All Pins"])
        #expect(pinned.items.first?.subtitle == "Click-through · 60 %")
        #expect(pinned.items[1].subtitle == nil)
        let toggle = pinned.items.first?.submenu?.items.first { $0.title == "Click-Through" }
        #expect(toggle?.state == .on)
    }

    @Test func aPinsCommandsShowItsState() {
        var state = PinState()
        state.isLocked = true
        state.showsBorder = false
        let items = PinsMenu.commandItems(for: state) { _ in }
        #expect(items.first?.view is PinOpacitySlider)
        let byTitle = Dictionary(items.map { ($0.title, $0) }, uniquingKeysWith: { first, _ in first })
        #expect(byTitle["Click-Through"]?.state == .off)
        #expect(byTitle["Lock Position"]?.state == .on)
        #expect(byTitle["Border and Shadow"]?.state == .off)
        for title in ["Zoom In", "Zoom Out", "Actual Size", "Copy", "Save", "Annotate", "Close"] {
            #expect(byTitle[title] != nil)
        }
        #expect(byTitle["Copy"]?.keyEquivalent == "c")
        #expect(PinsMenu.subtitle(for: state) == "Locked")
    }
}
