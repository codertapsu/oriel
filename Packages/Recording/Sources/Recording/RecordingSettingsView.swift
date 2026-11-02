import AppKit
import OrielCore
import Permissions
import SharedUI
import SwiftUI
import UniformTypeIdentifiers

/// The Recording pane of Settings (PLAN §10.1): quality, audio, overlays (with the camera background and the
/// clicks kept for Auto Zoom, PLAN §17), where movies go and GIF export.
struct RecordingSettingsView: View {
    private typealias Keys = RecordingSettingKeys

    let settings: SettingsStore
    let permissions: PermissionCenter
    @State private var microphones: [AudioInputDevice] = []
    @State private var isChoosingFolder = false

    var body: some View {
        Form {
            videoSection
            audioSection
            overlaySection
            outputSection
            gifSection
        }
        .formStyle(.grouped)
        .task { microphones = AudioInputDevice.available() }
    }

    private var videoSection: some View {
        let preset = settings[Keys.preset]
        return Section("Video") {
            Picker("Quality", selection: settings.binding(Keys.preset)) {
                ForEach(RecordingPreset.allCases) { Text($0.displayName).tag($0) }
            }
            Picker("Frame rate", selection: settings.binding(Keys.frameRate)) {
                Text("Preset (\(preset.frameRate) fps)").tag(Int?.none)
                let stored = settings[Keys.frameRate].flatMap { RecordingOptions.validFrameRates.contains($0) ? $0 : nil }
                ForEach(Self.choices(RecordingOptions.frameRates, including: stored), id: \.self) {
                    Text("\($0) fps").tag(Int?.some($0))
                }
            }
            Picker("Codec", selection: settings.binding(Keys.codec)) {
                Text("Preset (\(preset.codec.displayName))").tag(VideoCodec?.none)
                ForEach(VideoCodec.allCases) { Text($0.displayName).tag(VideoCodec?.some($0)) }
            }
            Toggle("Show the pointer", isOn: settings.binding(Keys.showsCursor))
        }
    }

    private var audioSection: some View {
        Section {
            Toggle("Record system audio", isOn: settings.binding(Keys.systemAudio))
            Toggle("Record the microphone", isOn: settings.binding(Keys.microphone))
            Picker("Microphone", selection: settings.binding(Keys.microphoneDeviceID)) {
                Text("System default").tag("")
                ForEach(microphones) { Text($0.name).tag($0.id) }
                let chosen = settings[Keys.microphoneDeviceID]
                if !chosen.isEmpty, !microphones.contains(where: { $0.id == chosen }) {
                    Text("Disconnected microphone").tag(chosen)
                }
            }
            .disabled(!settings[Keys.microphone])
            if settings[Keys.microphone] {
                permissionNote(.microphone, "Oriel may not use the microphone, so recordings will have no voice.")
            }
        } header: {
            Text("Audio")
        } footer: {
            Text("Oriel's own sounds are never recorded.")
        }
    }

    private var overlaySection: some View {
        Section("Overlays") {
            HStack {
                Toggle("Camera bubble", isOn: settings.binding(Keys.cameraBubble).gated(by: .cameraBubble))
                ProBadge(.cameraBubble)
            }
            if settings[Keys.cameraBubble], ProAccess.shared.allows(.cameraBubble) {
                permissionNote(.camera, "Oriel may not use the camera, so no camera bubble is shown.")
                CameraEffectSettingsView(settings: settings)
            }
            HStack {
                Toggle("Highlight clicks", isOn: settings.binding(Keys.clickRings).gated(by: .clickHighlights))
                ProBadge(.clickHighlights)
            }
            Toggle("Remember clicks for Auto Zoom", isOn: settings.binding(Keys.remembersClicks))
            if settings[Keys.remembersClicks] {
                Text("Each recording's clicks are saved in a small file next to it, so the video editor can zoom in on them.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if !Sandbox.isActive {
                Toggle("Show keystrokes", isOn: settings.binding(Keys.keystrokes).gated(by: .clickHighlights))
            }
            if !Sandbox.isActive, settings[Keys.keystrokes], permissions.status(of: .accessibility) != .granted {
                note(
                    "Showing keystrokes needs Accessibility, so that Oriel can see the keys you type in other apps. "
                        + "Recordings leave keystrokes out until it is granted.",
                    button: "Open Accessibility Settings"
                ) { permissions.openSystemSettings(for: .accessibility) }
            } else if settings[Keys.keystrokes] {
                Text("Keys typed into password fields are never shown.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var outputSection: some View {
        let folder = RecordingOptions.folder(fromPath: settings[Keys.outputFolder])
        return Section("Saving") {
            LabeledContent("Save recordings to") {
                Text(folder.path(percentEncoded: false))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(folder.path(percentEncoded: false))
            }
            HStack {
                Button("Choose…") { isChoosingFolder = true }
                Button("Show in Finder") {
                    _ = try? AppPaths.ensureDirectory(folder)
                    NSWorkspace.shared.activateFileViewerSelecting([folder])
                }
                if !settings[Keys.outputFolder].isEmpty {
                    Button("Use Default Folder") { settings.reset(Keys.outputFolder) }
                }
            }
            .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
                if case let .success(url) = result {
                    settings[Keys.outputFolder] = url.path(percentEncoded: false)
                }
            }
        }
    }

    private var gifSection: some View {
        Section("GIF export") {
            Picker("Maximum width", selection: settings.binding(Keys.gifMaxWidth)) {
                ForEach(Self.choices([480, 640, 800, 1024, 1280], including: settings[Keys.gifMaxWidth]), id: \.self) {
                    Text("\($0) px").tag($0)
                }
            }
            Picker("Frame rate", selection: settings.binding(Keys.gifFrameRate)) {
                ForEach(Array(GIFExportOptions.frameRates), id: \.self) { Text("\($0) fps").tag($0) }
            }
        }
    }

    /// `options`, plus the stored value when a bootstrap file set a usable one they do not offer, so the picker
    /// shows what is in effect.
    private static func choices(_ options: [Int], including current: Int?) -> [Int] {
        guard let current, current > 0, !options.contains(current) else { return options }
        return (options + [current]).sorted()
    }

    @ViewBuilder
    private func permissionNote(_ kind: PermissionKind, _ message: String) -> some View {
        if permissions.status(of: kind) == .denied {
            note(message, button: "Open \(kind.displayName) Settings") { permissions.openSystemSettings(for: kind) }
        }
    }

    private func note(_ message: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button(button, action: action)
                .controlSize(.small)
        }
    }
}
