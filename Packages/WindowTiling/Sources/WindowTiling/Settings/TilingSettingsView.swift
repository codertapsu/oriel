import AppKit
import OrielCore
import SwiftUI

/// Settings → Window Tiling: Accessibility, how a half cycles, the gap between windows, Almost Maximize's size, and the
/// shortcuts as they are now (they are changed in Settings → Shortcuts).
struct TilingSettingsView: View {
    let model: TilingSettingsModel

    private static let intro = """
    Arranges the focused window of the app you are in: halves, quarters, thirds, two thirds, maximize and center, \
    another display, a step smaller or larger, and back to where it was with Restore. Use the shortcuts below or the \
    menu bar's Window Tiling menu.
    """

    private static let layoutNote = """
    Gaps go between tiled windows and along the screen's edges. Windows that cannot take a size keep the layout's \
    edge and stay on the screen. Full-screen windows are left alone.
    """

    var body: some View {
        if let settings = model.settings {
            form(settings)
        }
    }

    private func form(_ settings: SettingsStore) -> some View {
        Form {
            Section("Window Tiling") {
                if !model.isActive {
                    note("Window Tiling is off. Turn it on in General → Tools.")
                }
                if !model.isTrusted {
                    LabeledContent("Accessibility") {
                        HStack {
                            Text("Not allowed").foregroundStyle(.orange)
                            Button("Open System Settings") { model.openAccessibilitySettings() }
                        }
                    }
                    note(PermissionKind.accessibility.settingsHint())
                }
                note(Self.intro)
            }
            Section("Layouts") {
                Toggle("Pressing a half again makes it two thirds, then one third", isOn: settings.binding(TilingSettings.cyclesSizes))
                LabeledContent("Gap between windows") {
                    HStack {
                        Slider(value: settings.binding(TilingSettings.gap), in: 0 ... 32, step: 2)
                            .frame(maxWidth: 220)
                            .accessibilityValue(Self.gapText(settings[TilingSettings.gap]))
                        valueText(Self.gapText(settings[TilingSettings.gap]))
                    }
                }
                LabeledContent("Almost Maximize") {
                    HStack {
                        Slider(value: settings.binding(TilingSettings.almostMaximizeFraction), in: 0.6 ... 0.95, step: 0.05)
                            .frame(maxWidth: 220)
                            .accessibilityValue(Self.percentText(settings[TilingSettings.almostMaximizeFraction]))
                        valueText(Self.percentText(settings[TilingSettings.almostMaximizeFraction]))
                    }
                }
                note(Self.layoutNote)
            }
            Section("Shortcuts") {
                shortcutGrid
                note("Change them in Settings → Shortcuts.")
            }
        }
        .formStyle(.grouped)
        .task {
            model.refresh()
            // Coming back from System Settings: show whether Accessibility is allowed now.
            let activations = NotificationCenter.default.notifications(named: NSApplication.didBecomeActiveNotification).map { _ in () }
            for await _ in activations {
                model.refresh()
            }
        }
    }

    /// Two related actions to a row: each half with its opposite, each pair of corners, and so on.
    nonisolated static let shortcutRows: [[TilingAction]] = [
        [.leftHalf, .rightHalf], [.topHalf, .bottomHalf], [.topLeft, .topRight], [.bottomLeft, .bottomRight],
        [.firstThird, .lastThird], [.firstTwoThirds, .lastTwoThirds], [.centerThird, .center], [.maximize, .almostMaximize],
        [.maximizeHeight, .restore], [.smaller, .larger], [.previousDisplay, .nextDisplay],
    ]

    private var shortcutGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
            ForEach(Self.shortcutRows, id: \.first) { row in
                GridRow {
                    ForEach(row, id: \.self) { action in
                        Text(action.title)
                        Text(model.shortcut(for: action) ?? "None")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .gridColumnAlignment(.trailing)
                            .padding(.trailing, 12)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func valueText(_ text: String) -> some View {
        Text(text)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(minWidth: 44, alignment: .trailing)
            .accessibilityHidden(true)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    static func gapText(_ gap: Double) -> String {
        gap < 1 ? "None" : "\(Int(gap.rounded())) pt"
    }

    static func percentText(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded())) %"
    }
}
