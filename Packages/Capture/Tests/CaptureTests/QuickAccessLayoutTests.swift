@testable import Capture
import CoreGraphics
import Testing

struct QuickAccessLayoutTests {
    private let visible = CGRect(x: 0, y: 40, width: 1512, height: 900)
    private let card = CGSize(width: 240, height: 200)

    @Test func cardsStackUpFromABottomCornerNewestFirst() {
        let frames = QuickAccessLayout.frames(count: 3, cardSize: card, in: visible, corner: .bottomRight)
        #expect(frames == [
            CGRect(x: 1256, y: 56, width: 240, height: 200),
            CGRect(x: 1256, y: 266, width: 240, height: 200),
            CGRect(x: 1256, y: 476, width: 240, height: 200),
        ])
    }

    @Test func topCornersStackDownwards() {
        let frames = QuickAccessLayout.frames(count: 2, cardSize: card, in: visible, corner: .topLeft)
        #expect(frames == [
            CGRect(x: 16, y: 724, width: 240, height: 200),
            CGRect(x: 16, y: 514, width: 240, height: 200),
        ])
    }

    @Test func onlyTheCardsThatFitGetAFrame() {
        #expect(QuickAccessLayout.capacity(cardHeight: 200, in: visible, margin: 16, spacing: 10) == 4)
        #expect(QuickAccessLayout.frames(count: 9, cardSize: card, in: visible, corner: .bottomLeft).count == 4)
        #expect(QuickAccessLayout.frames(count: 0, cardSize: card, in: visible, corner: .bottomLeft).isEmpty)
        // A screen too small for one card still shows the newest.
        let tiny = CGRect(x: 0, y: 0, width: 300, height: 100)
        #expect(QuickAccessLayout.frames(count: 2, cardSize: card, in: tiny, corner: .topRight).count == 1)
    }
}
