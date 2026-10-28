import CoreGraphics
@testable import WindowSwitcher

/// Captures solid images and records how many captures overlap.
actor FakeCapturer: WindowCapturing {
    private(set) var inFlight = 0
    private(set) var maximumInFlight = 0
    private(set) var captured: [UInt32] = []
    private(set) var prepared: [Set<UInt32>] = []
    /// Windows that cannot be captured (minimized ones, say).
    var failing: Set<UInt32> = []

    func setFailing(_ ids: Set<UInt32>) {
        failing = ids
    }

    func prepare(windowIDs: Set<UInt32>) {
        prepared.append(windowIDs)
    }

    func capture(windowID: UInt32, pixelSize: CGSize) async -> CGImage? {
        inFlight += 1
        maximumInFlight = max(maximumInFlight, inFlight)
        // Let other captures start, as real ones would while ScreenCaptureKit works.
        for _ in 0 ..< 5 {
            await Task.yield()
        }
        inFlight -= 1
        captured.append(windowID)
        guard !failing.contains(windowID) else { return nil }
        return TestImage.make(width: Int(pixelSize.width), height: Int(pixelSize.height))
    }
}
