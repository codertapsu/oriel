import AppKit
import SwiftUI

/// The fill of the background: transparent, a solid colour, a linear or radial gradient between two colours, or a
/// picture (the desktop picture or a chosen image), with a blur for pictures.
struct BackgroundFillSection: View {
    let tool: BackgroundTool
    /// Picture was chosen but no picture is set yet: show the ways to get one.
    @State private var wantsPicture = false

    private var session: EditorSession {
        tool.session
    }

    private var background: BackgroundStyle? {
        session.document.background
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Fill", selection: fill) {
                Text("Clear").tag(BackgroundStyle.Fill.none)
                Text("Solid").tag(BackgroundStyle.Fill.solid)
                Text("Linear").tag(BackgroundStyle.Fill.gradient)
                Text("Radial").tag(BackgroundStyle.Fill.radial)
                Text("Picture").tag(BackgroundStyle.Fill.image)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Fill")
            switch fill.wrappedValue {
            case .solid:
                ColorPicker("Colour", selection: color(at: 0), supportsOpacity: false)
            case .gradient, .radial:
                HStack(spacing: 14) {
                    ColorPicker(fill.wrappedValue == .radial ? "Centre" : "From", selection: color(at: 0), supportsOpacity: false)
                    ColorPicker(fill.wrappedValue == .radial ? "Edge" : "To", selection: color(at: 1), supportsOpacity: false)
                }
                if fill.wrappedValue == .gradient {
                    Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                        SliderRow(
                            title: "Angle",
                            value: Binding(get: { background?.angle ?? 45 }, set: { session.setGradientAngle($0) }),
                            range: 0 ... 360,
                            format: { "\(Int($0.rounded()))°" }
                        )
                    }
                }
            case .image:
                pictureControls
            case .none:
                Text("Only the shadow, corners and frame show.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var pictureControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button("Desktop Picture") {
                    Task { await tool.useDesktopPicture() }
                }
                Button("Choose…") {
                    tool.choosePicture()
                }
                if tool.isLoading {
                    ProgressView().controlSize(.small)
                }
            }
            .controlSize(.small)
            if background?.image != nil {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                    SliderRow(
                        title: "Blur",
                        value: Binding(get: { Double(background?.image?.blur ?? 0) }, set: { session.setBackgroundBlur(CGFloat($0)) }),
                        range: Double(BackgroundImage.blurRange.lowerBound) ... Double(BackgroundImage.blurRange.upperBound)
                    )
                }
            }
        }
    }

    private var fill: Binding<BackgroundStyle.Fill> {
        Binding(
            get: { wantsPicture ? .image : background?.fill ?? .none },
            set: { newValue in
                if newValue == .image, background?.image == nil {
                    wantsPicture = true
                } else {
                    wantsPicture = false
                    session.setFill(newValue)
                }
            }
        )
    }

    private func color(at index: Int) -> Binding<Color> {
        Binding(
            get: {
                let colors = background?.colors ?? []
                let color = colors.indices.contains(index) ? colors[index] : colors.last ?? .white
                return Color(cgColor: color.cgColor)
            },
            set: { newValue in
                if let color = RGBAColor(NSColor(newValue)) {
                    session.setFillColor(color, at: index)
                }
            }
        )
    }
}
