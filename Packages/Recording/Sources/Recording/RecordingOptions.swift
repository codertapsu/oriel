import Foundation
import OrielCore

/// The settings one recording uses, read once when it starts, so changing settings mid-recording changes nothing.
nonisolated struct RecordingOptions: Sendable, Equatable {
    /// The frame rates settings offer besides the preset's.
    static let frameRates = [15, 24, 30, 60]
    /// The frame rates a stored setting may have; anything else falls back to the preset's.
    static let validFrameRates = 1 ... 120

    var preset: RecordingPreset
    var frameRate: Int
    var codec: VideoCodec
    var showsCursor: Bool
    var systemAudio: Bool
    var microphone: Bool
    /// nil records the system default input.
    var microphoneDeviceID: String?
    var cameraBubble: Bool
    var clickRings: Bool
    var keystrokes: Bool
    /// Whether clicks are kept for Auto Zoom (PLAN §17).
    var remembersClicks: Bool
    /// What the camera bubble shows behind the person; `.unchanged` when the Mac cannot run the effect.
    var cameraBackground: CameraBackground
    var outputFolder: URL
    var gif: GIFExportOptions

    init(
        preset: RecordingPreset = .standard,
        frameRate: Int? = nil,
        codec: VideoCodec? = nil,
        showsCursor: Bool = true,
        systemAudio: Bool = true,
        microphone: Bool = false,
        microphoneDeviceID: String? = nil,
        cameraBubble: Bool = false,
        clickRings: Bool = false,
        keystrokes: Bool = false,
        remembersClicks: Bool = true,
        cameraBackground: CameraBackground = .unchanged,
        outputFolder: URL = AppPaths.recordings,
        gif: GIFExportOptions = GIFExportOptions()
    ) {
        self.preset = preset
        if let frameRate, Self.validFrameRates.contains(frameRate) {
            self.frameRate = frameRate
        } else {
            self.frameRate = preset.frameRate
        }
        self.codec = codec ?? preset.codec
        self.showsCursor = showsCursor
        self.systemAudio = systemAudio
        self.microphone = microphone
        self.microphoneDeviceID = microphoneDeviceID.flatMap { $0.isEmpty ? nil : $0 }
        self.cameraBubble = cameraBubble
        self.clickRings = clickRings
        self.keystrokes = keystrokes
        self.remembersClicks = remembersClicks
        self.cameraBackground = cameraBackground
        self.outputFolder = outputFolder
        self.gif = gif
    }

    @MainActor
    init(settings: SettingsStore) {
        typealias Keys = RecordingSettingKeys
        self.init(
            preset: settings[Keys.preset],
            frameRate: settings[Keys.frameRate],
            codec: settings[Keys.codec],
            showsCursor: settings[Keys.showsCursor],
            systemAudio: settings[Keys.systemAudio],
            microphone: settings[Keys.microphone],
            microphoneDeviceID: settings[Keys.microphoneDeviceID],
            // Pro features stay off without Oriel Pro (PLAN §19); keystrokes need Accessibility, which the App Store
            // edition's sandbox cannot be granted.
            cameraBubble: settings[Keys.cameraBubble] && ProAccess.shared.allows(.cameraBubble),
            clickRings: settings[Keys.clickRings] && ProAccess.shared.allows(.clickHighlights),
            keystrokes: settings[Keys.keystrokes] && ProAccess.shared.allows(.clickHighlights) && !Sandbox.isActive,
            remembersClicks: settings[Keys.remembersClicks],
            cameraBackground: CameraBackground.resolve(
                blurs: settings[Keys.blursCameraBackground],
                style: settings[Keys.cameraBackgroundStyle],
                colorHex: settings[Keys.cameraBackgroundColor],
                gate: CameraBackground.gate
            ),
            outputFolder: Self.folder(fromPath: settings[Keys.outputFolder], bookmark: settings[Keys.outputFolderBookmark]),
            gif: GIFExportOptions(frameRate: settings[Keys.gifFrameRate], maxWidth: settings[Keys.gifMaxWidth])
        )
    }

    /// The configured folder, or `AppPaths.recordings` when none is set. `~` is expanded. In the App Store edition the
    /// configured folder comes from its bookmark and the default is Movies/Oriel: there `AppPaths.recordings` lies in
    /// the container, which is not for the user's files (App Review Guidelines 2.4.5(i), PLAN §19.1).
    static func folder(fromPath path: String, bookmark: Data? = nil, sandboxed: Bool = Sandbox.isActive) -> URL {
        if sandboxed {
            return bookmark.flatMap(FolderBookmark.resolve) ?? moviesFolder
        }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return AppPaths.recordings }
        return URL(filePath: (trimmed as NSString).expandingTildeInPath, directoryHint: .isDirectory)
    }

    /// Movies/Oriel at its real path, which `com.apple.security.assets.movies.read-write` opens. In the sandbox the
    /// Movies folder FileManager names is a link inside the container, which Settings and Finder would show.
    static var moviesFolder: URL {
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Movies", directoryHint: .isDirectory)
        return movies.resolvingSymlinksInPath().appending(path: "Oriel", directoryHint: .isDirectory)
    }
}
