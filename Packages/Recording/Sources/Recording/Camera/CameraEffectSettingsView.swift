import AppKit
import AVFoundation
import OrielCore
import SwiftUI

/// The camera bubble's background settings in Settings → Recording (PLAN §17): macOS's own Portrait effect,
/// with its state and a way to its controls, and Oriel's "Blur camera background", which is hidden on Macs that
/// cannot run it.
struct CameraEffectSettingsView: View {
    private typealias Keys = RecordingSettingKeys

    let settings: SettingsStore
    @State private var portraitIsOn = AVCaptureDevice.isPortraitEffectEnabled

    var body: some View {
        if CameraBackground.gate.isOpen {
            Toggle("Blur camera background", isOn: settings.binding(Keys.blursCameraBackground))
            if settings[Keys.blursCameraBackground] {
                Picker("Background", selection: settings.binding(Keys.cameraBackgroundStyle)) {
                    ForEach(CameraBackgroundStyle.allCases) { Text($0.title).tag($0) }
                }
                if settings[Keys.cameraBackgroundStyle] == .color {
                    ColorPicker("Color", selection: color, supportsOpacity: false)
                }
                Text(
                    "Oriel finds you in the picture, on this Mac, and blurs or replaces the rest. It steps aside while "
                        + "the Portrait effect is on, and stops if the Mac gets too busy."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        LabeledContent("Portrait effect") {
            HStack {
                Text(portraitIsOn ? "On" : "Off")
                    .foregroundStyle(.secondary)
                Button("Video Effects…") {
                    AVCaptureDevice.showSystemUserInterface(.videoEffects)
                }
            }
        }
        .task { await followPortraitEffect() }
        Text(
            "macOS blurs the background in the camera itself. Its Video Effects are available while the camera "
                + "bubble is on, during a recording."
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    /// The color as the picker sees it, stored as `#RRGGBB`.
    private var color: Binding<CGColor> {
        Binding(
            get: {
                let rgb = CameraBackground.components(fromHex: settings[Keys.cameraBackgroundColor])
                    ?? CameraBackground.components(fromHex: CameraBackgroundStyle.defaultColorHex) ?? (0, 0, 0)
                return CGColor(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
            },
            set: { color in
                guard let srgb = CGColorSpace(name: CGColorSpace.sRGB),
                      let converted = color.converted(to: srgb, intent: .defaultIntent, options: nil),
                      let parts = converted.components, parts.count >= 3
                else { return }
                settings[Keys.cameraBackgroundColor] = CameraBackground.hex(red: parts[0], green: parts[1], blue: parts[2])
            }
        )
    }

    /// The Portrait effect is switched in Control Center, so its state is read again whenever Oriel or a window
    /// comes forward.
    private func followPortraitEffect() async {
        portraitIsOn = AVCaptureDevice.isPortraitEffectEnabled
        for await _ in NotificationCenter.default.notifications(named: NSWindow.didBecomeKeyNotification) {
            portraitIsOn = AVCaptureDevice.isPortraitEffectEnabled
        }
    }
}
