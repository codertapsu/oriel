import AppKit
import SharedUI

/// The recording control bar (PLAN §7.4, §10.2): a glass floating panel with the elapsed time, a microphone
/// indicator, pause/resume and stop. The stream's filter excludes its window, so it never appears in the video.
/// It never takes focus from the app being recorded; drag it by its background to move it.
final class RecordingControlBar {
    /// Pause or resume was clicked.
    var onTogglePause: (() -> Void)?
    /// Stop was clicked.
    var onStop: (() -> Void)?

    private let panel = FloatingPanel(level: .popUpMenu)
    private let statusIcon = NSImageView()
    private let timeLabel = NSTextField(labelWithString: "0:00")
    private let microphoneIcon = NSImageView()
    private let spinner = NSProgressIndicator()
    private lazy var pauseButton = HUDButton(symbol: "pause.fill", label: "Pause Recording") { [weak self] in
        self?.onTogglePause?()
    }

    private lazy var stopButton = HUDButton(symbol: "stop.fill", label: "Stop Recording") { [weak self] in
        self?.onStop?()
    }

    init(microphoneOn: Bool) {
        panel.isMovableByWindowBackground = true
        panel.setAccessibilityLabel("Recording controls")
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        timeLabel.setAccessibilityLabel("Elapsed time")
        let microphone = microphoneOn ? "mic.fill" : "mic.slash.fill"
        let microphoneHelp = microphoneOn ? "The microphone is recorded" : "The microphone is not recorded"
        microphoneIcon.image = NSImage(systemSymbolName: microphone, accessibilityDescription: microphoneHelp)
        microphoneIcon.contentTintColor = microphoneOn ? .labelColor : .tertiaryLabelColor
        microphoneIcon.toolTip = microphoneHelp
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        setPaused(false)

        let stack = NSStackView(views: [statusIcon, timeLabel, microphoneIcon, spinner, pauseButton, stopButton])
        stack.spacing = 8
        stack.setCustomSpacing(12, after: microphoneIcon)
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let background = Material.make(cornerRadius: 20)
        background.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.contentView.bottomAnchor),
            timeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])
        panel.contentView = background
    }

    /// The panel's window number, which ScreenCaptureKit's `SCWindow.windowID` matches once it is on screen.
    var windowID: CGWindowID {
        CGWindowID(clamping: panel.windowNumber)
    }

    /// Places the bar next to `captureRect` (Cocoa screen coordinates) and shows it.
    func show(near captureRect: CGRect, on screen: NSScreen?) {
        let fitting = panel.contentView?.fittingSize ?? .zero
        let size = fitting.width >= 100 && fitting.height >= 28 ? fitting : CGSize(width: 220, height: 40)
        let visible = screen?.visibleFrame ?? captureRect
        panel.setFrame(OverlayLayout.controlBarFrame(size: size, captureRect: captureRect, visibleFrame: visible), display: true)
        panel.orderFrontRegardless()
    }

    func update(elapsed: Duration) {
        timeLabel.stringValue = ElapsedTime.string(elapsed)
        timeLabel.setAccessibilityValue(ElapsedTime.spoken(elapsed))
    }

    func setPaused(_ paused: Bool) {
        let status = paused ? "pause.circle.fill" : "record.circle.fill"
        statusIcon.image = NSImage(systemSymbolName: status, accessibilityDescription: paused ? "Paused" : "Recording")
        statusIcon.contentTintColor = paused ? .secondaryLabelColor : .systemRed
        let title = paused ? "Resume Recording" : "Pause Recording"
        pauseButton.image = NSImage(systemSymbolName: paused ? "play.fill" : "pause.fill", accessibilityDescription: title)
        pauseButton.toolTip = title
        pauseButton.setAccessibilityLabel(title)
    }

    /// Shows that the movie is being saved; the buttons stop responding.
    func setFinishing() {
        pauseButton.isEnabled = false
        stopButton.isEnabled = false
        spinner.startAnimation(nil)
        timeLabel.stringValue = "Saving…"
    }

    func close() {
        spinner.stopAnimation(nil)
        panel.orderOut(nil)
        panel.close()
    }
}
