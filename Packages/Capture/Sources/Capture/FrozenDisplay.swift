import CoreGraphics

/// One display as it looked when the capture began: ScreenCaptureKit's image of it and where it is.
nonisolated struct FrozenDisplay: Sendable {
    let display: DisplayFrame
    /// SDR, in the display's colour space, at its native pixel size.
    let image: CGImage
    /// The HDR version (extended sRGB), only when HDR HEIC is on and the Mac can capture HDR.
    let hdrImage: CGImage?

    var id: CGDirectDisplayID {
        display.id
    }
}
