import AppKit

/// The system color loupe (`NSColorSampler`, macOS 10.15). It needs no Screen Recording permission: macOS draws the
/// loupe itself and hands Oriel only the color that was clicked, in the color space of the display it came from.
/// That color is converted to extended sRGB, so a wide-gamut color keeps its exact value. The session keeps its
/// sampler alive until the user clicks or presses Esc.
final class ScreenColorSampler: ColorSampling {
    func sample() async -> ColorValue? {
        guard let color = await NSColorSampler().sample() else { return nil }
        return ColorValue(color)
    }
}
