import OrielCore

/// The Recording pane's settings. Every name starts with `recording.`, so
/// `SettingsStore.removeAll(withPrefix: RecordingSettingKeys.prefix)` resets the pane.
public nonisolated enum RecordingSettingKeys {
    /// The prefix every Recording setting name starts with.
    public static let prefix = "recording."

    /// The quality preset.
    public static let preset = SettingKey<RecordingPreset>("recording.preset", default: .standard)
    /// Frames per second; nil uses the preset's rate.
    public static let frameRate = SettingKey<Int?>("recording.frameRate", default: nil)
    /// The video codec; nil uses the preset's codec.
    public static let codec = SettingKey<VideoCodec?>("recording.codec", default: nil)
    /// Whether the pointer is drawn into the video.
    public static let showsCursor = SettingKey("recording.showsCursor", default: true)
    /// Whether the sound other apps play is recorded. Oriel's own sounds never are.
    public static let systemAudio = SettingKey("recording.systemAudio", default: true)
    /// Whether the microphone is recorded (needs the Microphone permission).
    public static let microphone = SettingKey("recording.microphone", default: false)
    /// The `AVCaptureDevice.uniqueID` of the microphone; empty uses the system default input.
    public static let microphoneDeviceID = SettingKey("recording.microphoneDeviceID", default: "")
    /// Whether a round camera bubble is shown and recorded (needs the Camera permission).
    public static let cameraBubble = SettingKey("recording.cameraBubble", default: false)
    /// Whether clicks are highlighted with a fading ring.
    public static let clickRings = SettingKey("recording.clickRings", default: false)
    /// Whether keystrokes are shown in a HUD (needs Accessibility to observe keys in other apps).
    public static let keystrokes = SettingKey("recording.keystrokes", default: false)
    /// A folder path for finished recordings; empty uses `AppPaths.recordings`.
    public static let outputFolder = SettingKey("recording.outputFolder", default: "")
    /// The widest a GIF export may be, in pixels.
    public static let gifMaxWidth = SettingKey("recording.gifMaxWidth", default: 800)
    /// Frames per second of a GIF export (10–15).
    public static let gifFrameRate = SettingKey("recording.gifFrameRate", default: 10)
    /// Whether clicks are kept next to each recording (`<name>.oriel-clicks.json`) for the video editor's Auto
    /// Zoom.
    static let remembersClicks = SettingKey("recording.remembersClicks", default: true)
    /// Whether the camera bubble blurs or replaces the background behind the person (Apple silicon only).
    static let blursCameraBackground = SettingKey("recording.blursCameraBackground", default: false)
    /// How the camera background is treated when `blursCameraBackground` is on.
    static let cameraBackgroundStyle = SettingKey("recording.cameraBackgroundStyle", default: CameraBackgroundStyle.blur)
    /// The color behind the person when `cameraBackgroundStyle` is `.color`, as `#RRGGBB`.
    static let cameraBackgroundColor = SettingKey("recording.cameraBackgroundColor", default: CameraBackgroundStyle.defaultColorHex)
    /// Auto Zoom's zoom level in the video editor (1.5–3).
    static let autoZoomLevel = SettingKey("recording.autoZoomLevel", default: 2.0)
    /// How long Auto Zoom holds after a click, in seconds (0.5–5).
    static let autoZoomHold = SettingKey("recording.autoZoomHold", default: 1.5)
    /// The video editor's last export choices.
    static let editorExportFormat = SettingKey("recording.editorExportFormat", default: VideoExportFormat.mp4)
    static let editorExportCodec = SettingKey<VideoCodec?>("recording.editorExportCodec", default: nil)
    static let editorExportSize = SettingKey("recording.editorExportSize", default: VideoExportSize.original)
}
