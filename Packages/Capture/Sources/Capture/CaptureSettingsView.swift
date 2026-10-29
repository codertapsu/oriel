import AppKit
import OrielCore
import SwiftUI

/// Settings → Capture (PLAN §10.1): what happens after a capture, where files go and how they are named and encoded,
/// capture options, the Quick Access Overlay, history and scrolling capture.
struct CaptureSettingsView: View {
    let settings: SettingsStore
    /// On-device OCR is there, so Capture Text is offered.
    let showsTextCapture: Bool
    let onShowHistory: () -> Void
    let onClearHistory: () -> Void
    @State private var confirmsClear = false

    private static let frozenNote = "Menus and hover states stay in the shot. Turn this off to capture video as it plays."
    private static let liveNote = """
    The screen keeps playing while you select, and Oriel captures it when you finish. Open menus close, and there is \
    no magnifier.
    """

    var body: some View {
        Form {
            Section("After Capture") {
                Picker("After a capture", selection: settings.binding(CaptureSettings.afterCapture)) {
                    ForEach(AfterCaptureAction.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Copy every capture to the clipboard", isOn: settings.binding(CaptureSettings.copiesToClipboard))
                Text("It is also kept in Clipboard History, even when you close Quick Access with Esc.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Quick Access closes after", selection: settings.binding(CaptureSettings.quickAccessSeconds)) {
                    ForEach(CaptureSettings.quickAccessChoices, id: \.self) { seconds in
                        Text(seconds == 0 ? "Never" : "\(seconds) seconds").tag(seconds)
                    }
                }
                Picker("Quick Access corner", selection: settings.binding(CaptureSettings.quickAccessCorner)) {
                    ForEach(ScreenCorner.allCases) { Text($0.title).tag($0) }
                }
            }
            files
            Section("Capture") {
                Toggle("Play a sound", isOn: settings.binding(CaptureSettings.playsSound))
                Toggle("Flash the captured area", isOn: settings.binding(CaptureSettings.flashes))
                Toggle("Include the pointer", isOn: settings.binding(CaptureSettings.showsCursor))
                Toggle("Include window shadows", isOn: settings.binding(CaptureSettings.windowShadow))
                Toggle("Hide desktop icons and widgets", isOn: settings.binding(CaptureSettings.hidesDesktopIcons))
                Text("Captures of an area or a screen show the wallpaper without them. Finder is not changed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Freeze the screen while selecting", isOn: settings.binding(CaptureSettings.freezesScreen))
                Text(settings[CaptureSettings.freezesScreen] ? Self.frozenNote : Self.liveNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Show the magnifier while selecting", isOn: settings.binding(CaptureSettings.showsMagnifier))
                    .disabled(!settings[CaptureSettings.freezesScreen])
                Picker("Timer", selection: settings.binding(CaptureSettings.timerSeconds)) {
                    ForEach(CaptureSettings.timerChoices, id: \.self) { Text("\($0) seconds").tag($0) }
                }
                Picker("Scrolling capture stops at", selection: settings.binding(CaptureSettings.scrollingMaxLength)) {
                    ForEach([5000, 10000, 20000, 30000], id: \.self) { Text("\($0.formatted()) pixels").tag($0) }
                }
            }
            if showsTextCapture {
                Section("Capture Text") {
                    Toggle("Open captured text for editing", isOn: settings.binding(CaptureSettings.textOpensPanel))
                    Text(textNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            history
        }
        .formStyle(.grouped)
        .confirmationDialog("Delete every capture in history?", isPresented: $confirmsClear) {
            Button("Delete All", role: .destructive, action: onClearHistory)
        }
    }

    private var files: some View {
        Section("Files") {
            LabeledContent("Save to") {
                HStack {
                    Text(folderName).lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
                    Button("Choose…", action: chooseFolder)
                }
            }
            TextField("File name", text: settings.binding(CaptureSettings.filenameTemplate))
            Text("\(FilenameTemplate.tokens.joined(separator: " ")) · for example “\(preview)”")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Format", selection: settings.binding(CaptureSettings.format)) {
                ForEach(CaptureImageFormat.allCases) { Text($0.title).tag($0) }
            }
            if settings[CaptureSettings.format] == .heic {
                Toggle("Keep HDR", isOn: settings.binding(CaptureSettings.keepsHDR))
                Text("HDR content stays bright on HDR displays; other displays show a normal image.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var history: some View {
        Section("History") {
            Toggle("Keep a history of captures", isOn: settings.binding(CaptureSettings.historyEnabled))
            Picker("Keep captures for", selection: settings.binding(CaptureSettings.historyRetentionDays)) {
                ForEach(CaptureSettings.retentionChoices, id: \.self) { days in
                    Text(days == 0 ? "Forever" : days == 1 ? "1 day" : "\(days) days").tag(days)
                }
            }
            HStack {
                Button("Open History…", action: onShowHistory)
                Button("Clear History…") { confirmsClear = true }
            }
        }
    }

    private var textNote: String {
        settings[CaptureSettings.textOpensPanel]
            ? "Capture Text opens what it reads, to correct it before copying. Hold ⇧ while selecting to copy it at once."
            : "Capture Text copies what it reads, keeping its lines. Hold ⇧ while selecting to edit it first."
    }

    private var folderName: String {
        guard let path = settings[CaptureSettings.saveFolder] else { return "Desktop" }
        return (path as NSString).abbreviatingWithTildeInPath
    }

    private var preview: String {
        let context = FilenameTemplate.Context(
            date: Date(),
            kind: .area,
            appName: "Safari",
            windowTitle: "Start Page",
            pixelWidth: 1440,
            pixelHeight: 900
        )
        return FilenameTemplate.render(settings[CaptureSettings.filenameTemplate], context: context)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Choose where Oriel saves captures."
        if panel.runModal() == .OK, let url = panel.url {
            settings[CaptureSettings.saveFolder] = url.path
        }
    }
}
