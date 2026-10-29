@testable import Capture
import CoreGraphics
import Testing

/// How a pin's opacity, zoom, click-through and lock behave (PLAN §10.4, §17).
struct PinStateTests {
    @Test func opacityStaysBetweenTenPercentAndOpaque() {
        var state = PinState()
        #expect(state.opacity == 1 && state.opacityPercent == 100)
        state.setOpacity(0.02)
        #expect(state.opacity == 0.1)
        state.changeOpacity(by: 0.25)
        #expect(state.opacityPercent == 35)
        state.changeOpacity(by: 5)
        #expect(state.opacity == 1)
    }

    @Test func numberKeysSetTheOpacity() {
        #expect(PinState.opacity(forDigit: 1) == 0.1)
        #expect(PinState.opacity(forDigit: 6) == 0.6)
        #expect(PinState.opacity(forDigit: 9) == 0.9)
        #expect(PinState.opacity(forDigit: 0) == 1)
        #expect(PinState.opacity(forDigit: 10) == nil)
        #expect(PinState.opacity(forDigit: -1) == nil)
    }

    @Test func clickThroughHasAWayBack() {
        var state = PinState()
        #expect(!state.ignoresMouseEvents)
        state.isClickThrough = true
        #expect(state.ignoresMouseEvents)
        // ⌥⌘ held over the pin lets it take clicks again, so it can be moved or switched back.
        state.isHeldOpen = true
        #expect(!state.ignoresMouseEvents)
        // A scrolling capture always lets the mouse through, held or not.
        state.isPassingThrough = true
        #expect(state.ignoresMouseEvents)
        state.isClickThrough = false
        state.isHeldOpen = false
        #expect(state.ignoresMouseEvents)
        state.isPassingThrough = false
        #expect(!state.ignoresMouseEvents)
    }

    @Test func zoomStepsAndLimits() {
        var state = PinState()
        state.zoomIn()
        #expect(state.zoom == 1.25)
        state.setZoom(1)
        state.zoomOut()
        #expect(state.zoom == 0.75)
        state.setZoom(0.8)
        state.zoomIn()
        #expect(state.zoom == 1)
        state.setZoom(0.8)
        state.zoomOut()
        #expect(state.zoom == 0.75)
        state.setZoom(50)
        #expect(state.zoom == 8)
        state.zoomIn()
        #expect(state.zoom == 8)
        state.zoom(by: 0.001)
        #expect(state.zoom == 0.1 && state.zoomPercent == 10)
    }

    @Test func scrollingZoomsAndOptionScrollingFades() {
        #expect(PinState.zoomFactor(scrollDelta: 0, precise: true) == 1)
        #expect(PinState.zoomFactor(scrollDelta: 10, precise: true) > 1)
        #expect(PinState.zoomFactor(scrollDelta: -10, precise: true) < 1)
        #expect(PinState.zoomFactor(scrollDelta: 1, precise: false) > PinState.zoomFactor(scrollDelta: 1, precise: true))
        #expect(PinState.opacityChange(scrollDelta: 30, precise: true) == 0.1)
        #expect(PinState.opacityChange(scrollDelta: -2, precise: false) == -0.1)
    }

    @Test func zoomingKeepsThePointUnderThePointerInPlace() {
        let frame = CGRect(x: 100, y: 100, width: 200, height: 100)
        let doubled = PinState.frame(of: frame, resizedTo: CGSize(width: 400, height: 200), keeping: CGPoint(x: 200, y: 150))
        #expect(doubled == CGRect(x: 0, y: 50, width: 400, height: 200))
        let fromCorner = PinState.frame(of: frame, resizedTo: CGSize(width: 100, height: 50), keeping: CGPoint(x: 100, y: 100))
        #expect(fromCorner == CGRect(x: 100, y: 100, width: 100, height: 50))
        // An anchor outside the pin counts as its nearest edge.
        let outside = PinState.frame(of: frame, resizedTo: CGSize(width: 400, height: 200), keeping: CGPoint(x: 0, y: 0))
        #expect(outside == CGRect(x: 100, y: 100, width: 400, height: 200))
    }

    @Test func theSizeFollowsTheZoomButStaysGrabbable() {
        var state = PinState()
        let size = CGSize(width: 300, height: 120)
        #expect(state.size(for: size) == size)
        state.setZoom(2)
        #expect(state.size(for: size) == CGSize(width: 600, height: 240))
        state.setZoom(0.1)
        #expect(state.size(for: size) == CGSize(width: 30, height: 24))
    }
}
