import CoreGraphics
@testable import Editor
import Testing

/// Instant Capture's placement (PLAN §17): the panel exactly over the selection on the right display, the toolbar
/// below, above or inside it and always on screen. Synthetic layouts: a 2× laptop with the Dock at the bottom, a 1×
/// display to its left and one above it.
struct InstantPlacementTests {
    private let laptop = InstantPlacement.Screen(
        frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        visibleFrame: CGRect(x: 0, y: 70, width: 1440, height: 805),
        scale: 2
    )
    private let left = InstantPlacement.Screen(
        frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1055),
        scale: 1
    )
    private let above = InstantPlacement.Screen(
        frame: CGRect(x: 0, y: 900, width: 2560, height: 1440),
        visibleFrame: CGRect(x: 0, y: 900, width: 2560, height: 1415),
        scale: 1
    )
    private let toolbar = CGSize(width: 560, height: 36)

    private func place(_ selection: CGRect, toolbar: CGSize? = nil) throws -> InstantPlacement {
        try #require(InstantPlacement.place(
            selection: selection, screens: [laptop, left, above], primaryHeight: 900, toolbarSize: toolbar ?? self.toolbar
        ))
    }

    @Test func thePanelCoversTheSelectionAndTheToolbarSitsBelowIt() throws {
        let placement = try place(CGRect(x: 400, y: 200, width: 300, height: 200))
        // CoreGraphics y 200…400 is Cocoa y 500…700 on a 900-point primary display.
        #expect(placement.canvasFrame == CGRect(x: 400, y: 500, width: 300, height: 200))
        #expect(placement.panelFrame == CGRect(x: 398, y: 498, width: 304, height: 204))
        #expect(placement.screenIndex == 0 && placement.scale == 2)
        #expect(placement.toolbarPosition == .below)
        // Right-aligned with the selection, a gap below its outline.
        #expect(placement.toolbarFrame == CGRect(x: 140, y: 454, width: 560, height: 36))
        #expect(!placement.toolbarFrame.intersects(placement.panelFrame))
    }

    @Test func nearTheBottomTheToolbarGoesAbove() throws {
        let placement = try place(CGRect(x: 400, y: 760, width: 300, height: 100))
        #expect(placement.canvasFrame.minY == 40)
        #expect(placement.toolbarPosition == .above)
        #expect(placement.toolbarFrame.minY == 150)
        #expect(!placement.toolbarFrame.intersects(placement.panelFrame))
    }

    @Test func overTheWholeScreenTheToolbarGoesInsideAboveTheDock() throws {
        let placement = try place(CGRect(x: 0, y: 0, width: 1440, height: 900))
        #expect(placement.toolbarPosition == .inside)
        #expect(placement.toolbarFrame.minY == 76)
        #expect(laptop.visibleFrame.contains(placement.toolbarFrame))
    }

    @Test func theToolbarNeverLeavesTheScreenSideways() throws {
        let nearLeft = try place(CGRect(x: 10, y: 300, width: 100, height: 80))
        #expect(nearLeft.toolbarFrame.minX == 6)
        let nearRight = try place(CGRect(x: 1400, y: 300, width: 40, height: 40))
        #expect(nearRight.toolbarFrame.maxX == 1434)
        let tooWide = try place(CGRect(x: 600, y: 300, width: 100, height: 80), toolbar: CGSize(width: 2000, height: 36))
        #expect(tooWide.toolbarFrame.minX == 6)
    }

    @Test func aSelectionOnTheDisplayToTheLeftUsesItsScale() throws {
        let placement = try place(CGRect(x: -1500, y: 100, width: 400, height: 300))
        #expect(placement.screenIndex == 1 && placement.scale == 1)
        #expect(placement.canvasFrame == CGRect(x: -1500, y: 500, width: 400, height: 300))
        #expect(placement.toolbarPosition == .below)
        #expect(left.visibleFrame.contains(placement.toolbarFrame))
    }

    @Test func aSelectionOnTheDisplayAboveHasANegativeCoreGraphicsY() throws {
        let placement = try place(CGRect(x: 100, y: -1000, width: 400, height: 300))
        #expect(placement.screenIndex == 2)
        #expect(placement.canvasFrame == CGRect(x: 100, y: 1600, width: 400, height: 300))
        #expect(above.visibleFrame.contains(placement.toolbarFrame))
    }

    @Test func thePanelLandsOnTheDisplaysPixelGrid() throws {
        let placement = try place(CGRect(x: 100.3, y: 200.2, width: 50.5, height: 40.4))
        for edge in [placement.canvasFrame.minX, placement.canvasFrame.maxX, placement.canvasFrame.minY, placement.canvasFrame.maxY] {
            #expect((edge * 2).rounded() == edge * 2, "\(edge) is not on the 2× grid")
        }
        let toolbarOrigin = placement.toolbarFrame.origin
        #expect(toolbarOrigin.x.rounded() == toolbarOrigin.x && toolbarOrigin.y.rounded() == toolbarOrigin.y)
    }

    @Test func nothingToPlaceWithoutScreensOrAnArea() {
        #expect(InstantPlacement.place(
            selection: CGRect(x: 0, y: 0, width: 10, height: 10),
            screens: [],
            primaryHeight: 900,
            toolbarSize: toolbar
        ) == nil)
        #expect(InstantPlacement.place(selection: .zero, screens: [laptop], primaryHeight: 900, toolbarSize: toolbar) == nil)
    }
}
