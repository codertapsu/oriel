import SwiftUI

/// The canvas around the image: padding, the inset in the image's edge colour, the aspect (a ratio, a social
/// network's size or a custom pixel size) and where the image sits when the aspect leaves room.
struct BackgroundLayoutSection: View {
    let session: EditorSession
    /// Custom Size was chosen, even if the size typed so far is one of the named ones.
    @State private var showsCustomSize = false

    private var background: BackgroundStyle? {
        session.document.background
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Layout").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                SliderRow(
                    title: "Padding",
                    value: Binding(get: { Double(session.document.canvasPadding?.top ?? 0) }, set: { session.setPadding(CGFloat($0)) }),
                    range: Double(BackgroundStyle.paddingRange.lowerBound) ... Double(BackgroundStyle.paddingRange.upperBound)
                )
                SliderRow(
                    title: "Inset",
                    value: Binding(get: { Double(background?.inset ?? 0) }, set: { session.setInset(CGFloat($0)) }),
                    range: Double(BackgroundStyle.insetRange.lowerBound) ... Double(BackgroundStyle.insetRange.upperBound)
                )
                GridRow {
                    Text("Aspect")
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    Picker("Aspect", selection: aspectPreset) {
                        ForEach(AspectPreset.allCases) { preset in
                            if preset.startsGroup {
                                Divider()
                            }
                            Text(preset.title).tag(preset)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .gridCellColumns(2)
                }
                if aspectPreset.wrappedValue == .custom {
                    GridRow {
                        Text("Size")
                            .foregroundStyle(.secondary)
                            .gridColumnAlignment(.trailing)
                        HStack(spacing: 4) {
                            TextField("Width", value: customSize(\.width), format: .number.grouping(.never))
                                .frame(width: 64)
                                .accessibilityLabel("Width in pixels")
                            Text("×").foregroundStyle(.secondary)
                            TextField("Height", value: customSize(\.height), format: .number.grouping(.never))
                                .frame(width: 64)
                                .accessibilityLabel("Height in pixels")
                            Text("px").foregroundStyle(.secondary)
                        }
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .gridCellColumns(2)
                    }
                }
                if (background?.aspect ?? .auto) != .auto {
                    GridRow(alignment: .top) {
                        Text("Position")
                            .foregroundStyle(.secondary)
                            .gridColumnAlignment(.trailing)
                        AlignmentPicker(selection: background?.alignment ?? .center) { session.setAlignment($0) }
                            .gridCellColumns(2)
                    }
                }
            }
        }
    }

    private var aspectPreset: Binding<AspectPreset> {
        Binding(
            get: { showsCustomSize ? .custom : AspectPreset.matching(background?.aspect ?? .auto) },
            set: { preset in
                showsCustomSize = preset == .custom
                if let aspect = preset.aspect {
                    session.setAspect(aspect)
                } else if background?.aspect.pixelSize == nil {
                    // A custom size starts from what the image is exported at now.
                    let size = session.outputPixelSize
                    session.setAspect(.pixels(width: max(Int(size.width), 16), height: max(Int(size.height), 16)))
                }
            }
        )
    }

    private func customSize(_ side: KeyPath<PixelSize, Int>) -> Binding<Int> {
        Binding(
            get: { background?.aspect.pixelSize?[keyPath: side] ?? 0 },
            set: { newValue in
                var size = background?.aspect.pixelSize ?? PixelSize(width: 1200, height: 675)
                let clamped = min(max(newValue, CanvasAspect.pixelRange.lowerBound), CanvasAspect.pixelRange.upperBound)
                if side == \PixelSize.width {
                    size.width = clamped
                } else {
                    size.height = clamped
                }
                session.setAspect(.pixels(width: size.width, height: size.height))
            }
        )
    }
}
