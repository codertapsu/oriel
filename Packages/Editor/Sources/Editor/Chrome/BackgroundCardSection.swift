import SwiftUI

/// The image card: its corner radius, an optional window frame, and the shadow under it (blur, opacity, offset).
struct BackgroundCardSection: View {
    let session: EditorSession

    private var background: BackgroundStyle? {
        session.document.background
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Card").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                SliderRow(
                    title: "Corners",
                    value: Binding(get: { Double(background?.cornerRadius ?? 0) }, set: { session.setCornerRadius(CGFloat($0)) }),
                    range: Double(BackgroundStyle.cornerRadiusRange.lowerBound) ... Double(BackgroundStyle.cornerRadiusRange.upperBound)
                )
                GridRow {
                    Text("Frame")
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    Picker(
                        "Window frame",
                        selection: Binding(get: { background?.windowFrame ?? .none }, set: { session.setWindowFrame($0) })
                    ) {
                        ForEach(WindowFrame.allCases) { frame in
                            Text(frame.title).tag(frame)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.small)
                    .gridCellColumns(2)
                }
                GridRow {
                    Text("Shadow")
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    Toggle("Shadow", isOn: Binding(get: { background?.shadow ?? false }, set: { session.setShadow($0) }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .gridCellColumns(2)
                }
                if background?.shadow == true {
                    shadowSliders
                }
            }
        }
    }

    @ViewBuilder private var shadowSliders: some View {
        let shadow = session.currentShadow
        SliderRow(
            title: "Blur",
            value: Binding(get: { Double(shadow.radius) }, set: { value in
                session.setShadowStyle(
                    ShadowStyle(radius: CGFloat(value), opacity: shadow.opacity, offset: shadow.offset),
                    coalescing: "shadowBlur"
                )
            }),
            range: Double(ShadowStyle.radiusRange.lowerBound) ... Double(ShadowStyle.radiusRange.upperBound)
        )
        SliderRow(
            title: "Opacity",
            value: Binding(get: { shadow.opacity }, set: { value in
                session.setShadowStyle(
                    ShadowStyle(radius: shadow.radius, opacity: value, offset: shadow.offset),
                    coalescing: "shadowOpacity"
                )
            }),
            range: 0 ... 1,
            format: { "\(Int(($0 * 100).rounded())) %" }
        )
        SliderRow(
            title: "Offset X",
            value: Binding(get: { Double(shadow.offset.width) }, set: { value in
                let offset = CGSize(width: CGFloat(value), height: shadow.offset.height)
                session.setShadowStyle(ShadowStyle(radius: shadow.radius, opacity: shadow.opacity, offset: offset), coalescing: "shadowX")
            }),
            range: Double(ShadowStyle.offsetRange.lowerBound) ... Double(ShadowStyle.offsetRange.upperBound)
        )
        SliderRow(
            title: "Offset Y",
            value: Binding(get: { Double(shadow.offset.height) }, set: { value in
                let offset = CGSize(width: shadow.offset.width, height: CGFloat(value))
                session.setShadowStyle(ShadowStyle(radius: shadow.radius, opacity: shadow.opacity, offset: offset), coalescing: "shadowY")
            }),
            range: Double(ShadowStyle.offsetRange.lowerBound) ... Double(ShadowStyle.offsetRange.upperBound)
        )
    }
}
