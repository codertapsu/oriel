import CoreGraphics
import Foundation

/// The background tool (PLAN §17): presets, fills, padding, inset, aspect, alignment, corners, shadow and window
/// frame. Each change is one undo step; a slider drag is one step however far it goes.
extension EditorSession {
    /// Applies a preset's fill, keeping the current layout, corners, shadow and frame; adds padding if there is
    /// none. `.none` removes the background and the padding.
    func applyBackground(_ preset: BackgroundPreset) {
        commit("Background") { document in
            guard let style = preset.style else {
                document.background = nil
                document.canvasPadding = nil
                return
            }
            document.background = document.background?.withFill(of: style) ?? style
            if document.canvasPadding == nil {
                document.canvasPadding = Padding(all: BackgroundPreset.defaultPadding(for: document.visibleImageRect.size))
            }
        }
    }

    /// Applies a saved background as a whole: its fill, layout, corners, shadow and frame, and its padding.
    func applyBackground(_ style: BackgroundStyle, padding: CGFloat) {
        commit("Background") { document in
            document.background = style
            document.canvasPadding = Padding(all: max(0, padding))
        }
    }

    /// Changes the background, creating a transparent one with the default padding first if there is none, so any
    /// option of the panel can be the first one chosen.
    func updateBackground(_ actionName: String, coalescing key: String? = nil, _ change: (inout BackgroundStyle) -> Void) {
        commit(actionName, coalescing: key) { document in
            var style = document.background ?? BackgroundStyle(fill: .none)
            change(&style)
            if document.background == nil, document.canvasPadding == nil {
                document.canvasPadding = Padding(all: BackgroundPreset.defaultPadding(for: document.visibleImageRect.size))
            }
            document.background = style
        }
    }

    /// Switches the fill's kind. A gradient keeps the colours it has, or starts from the solid colour and a lighter
    /// shade of it; a picture needs an image first (`setBackgroundImage`), and leaving the picture drops it, so the
    /// document does not carry an image it no longer shows.
    func setFill(_ fill: BackgroundStyle.Fill) {
        guard fill != .image || document.background?.image != nil else { return }
        updateBackground("Background") { style in
            style.fill = fill
            if fill != .image {
                style.image = nil
            }
            switch fill {
            case .solid where style.colors.isEmpty:
                style.colors = [BackgroundPreset.rgb(0xF2F2F7)]
            case .gradient, .radial:
                if style.colors.count < 2 {
                    let first = style.colors.first ?? BackgroundPreset.rgb(0x2E8BFF)
                    style.colors = [first, Self.lighter(first)]
                }
            default:
                break
            }
        }
    }

    /// Replaces colour `index` of the fill (one undo step while the colour panel drags).
    func setFillColor(_ color: RGBAColor, at index: Int) {
        updateBackground("Background Colour", coalescing: "fillColor\(index)") { style in
            while style.colors.count <= index {
                style.colors.append(style.colors.last ?? color)
            }
            style.colors[index] = color.withAlpha(1)
        }
    }

    func setGradientAngle(_ degrees: Double) {
        updateBackground("Gradient Angle", coalescing: "angle") { $0.angle = degrees.rounded() }
    }

    /// Fills the background with a picture (the desktop picture or a chosen image).
    func setBackgroundImage(_ asset: ImageAsset, source: BackgroundImage.Source) {
        updateBackground("Background Picture") { style in
            style.image = BackgroundImage(asset: asset, source: source, blur: style.image?.blur ?? 0)
            style.fill = .image
        }
    }

    func setBackgroundBlur(_ blur: CGFloat) {
        guard document.background?.image != nil else { return }
        updateBackground("Picture Blur", coalescing: "pictureBlur") { $0.image?.blur = max(0, blur.rounded()) }
    }

    func setPadding(_ value: CGFloat) {
        commit("Padding", coalescing: "padding") { $0.canvasPadding = Padding(all: max(0, value.rounded())) }
    }

    func setInset(_ value: CGFloat) {
        updateBackground("Inset", coalescing: "inset") { $0.inset = max(0, value.rounded()) }
    }

    func setCornerRadius(_ value: CGFloat) {
        guard document.background != nil else { return }
        commit("Corner Radius", coalescing: "cornerRadius") { $0.background?.cornerRadius = max(0, value.rounded()) }
    }

    func setShadow(_ enabled: Bool) {
        guard document.background != nil else { return }
        commit("Shadow") { $0.background?.shadow = enabled }
    }

    /// Sets the shadow's blur, opacity and offset (one undo step per slider drag).
    func setShadowStyle(_ shadow: ShadowStyle, coalescing key: String) {
        guard document.background != nil else { return }
        // Whole points and whole percent, whatever the slider sends.
        let rounded = ShadowStyle(
            radius: shadow.radius.rounded(),
            opacity: (shadow.opacity * 100).rounded() / 100,
            offset: CGSize(width: shadow.offset.width.rounded(), height: shadow.offset.height.rounded())
        )
        commit("Shadow", coalescing: key) { document in
            document.background?.shadowStyle = rounded
            document.background?.shadow = true
        }
    }

    /// The shadow as drawn now, for the panel's sliders.
    var currentShadow: ShadowStyle {
        document.background?.resolvedShadow(padding: document.canvasPadding ?? .zero)
            ?? .automatic(padding: document.canvasPadding ?? .zero)
    }

    func setAspect(_ aspect: CanvasAspect) {
        updateBackground("Aspect Ratio") { $0.aspect = aspect }
    }

    func setAlignment(_ alignment: CanvasAlignment) {
        updateBackground("Alignment") { $0.alignment = alignment }
    }

    func setWindowFrame(_ frame: WindowFrame) {
        updateBackground("Window Frame") { $0.windowFrame = frame }
    }

    /// The colour nearly halfway to white, for the second colour of a new gradient.
    private static func lighter(_ color: RGBAColor) -> RGBAColor {
        RGBAColor(
            red: color.red + (1 - color.red) * 0.45,
            green: color.green + (1 - color.green) * 0.45,
            blue: color.blue + (1 - color.blue) * 0.45
        )
    }
}
