@testable import Capture
import CoreGraphics
import Testing

/// Frozen and live selections (PLAN §7.2, item 2): what each display's overlay shows.
struct SelectionScreensTests {
    private let left = DisplayFrame(id: 1, frame: CGRect(x: 0, y: 0, width: 20, height: 15), scale: 2)
    private let right = DisplayFrame(id: 2, frame: CGRect(x: 20, y: 0, width: 20, height: 15), scale: 1)

    @Test func frozenDisplaysShowTheirPictures() throws {
        let picture = try TestImages.quadrants(width: 40, height: 30)
        let frozen = [FrozenDisplay(display: left, image: picture, hdrImage: nil)]
        let backdrops = SelectionScreens.backdrops(displays: [left], frozen: frozen)
        #expect(backdrops.map(\.id) == [1])
        #expect(backdrops.first?.image === picture)
        #expect(backdrops.first?.display == left)
    }

    @Test func aLiveScreenShowsNoPictures() {
        let backdrops = SelectionScreens.backdrops(displays: [left, right], frozen: [])
        #expect(backdrops.map(\.id) == [1, 2])
        #expect(backdrops.allSatisfy { $0.image == nil })
    }

    @Test func theScreenFreezesUnlessTurnedOff() {
        #expect(CaptureSettings.freezesScreen.defaultValue)
    }
}
