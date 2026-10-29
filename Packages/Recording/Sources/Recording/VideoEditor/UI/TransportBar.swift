import AppKit

/// The bar between the video editor's preview and its timeline (PLAN §17): go to start, back, play or pause,
/// forward, the playhead's time, what the trim keeps, and the timeline's zoom.
final class TransportBar: NSView {
    /// A button was pressed.
    var onCommand: ((VideoEditorCommand) -> Void)?
    /// The zoom slider moved, from 0 (fitted) to 1.
    var onZoom: ((Double) -> Void)?

    private let timeLabel = NSTextField(labelWithString: "0:00.00")
    private let keptLabel = NSTextField(labelWithString: "")
    private let zoomSlider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private lazy var playButton = makeButton("play.fill", label: "Play", command: .playPause)
    /// What the play button shows, so playback's frequent updates change it only when it changes.
    private var showsPause: Bool?

    init() {
        super.init(frame: .zero)
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        timeLabel.setAccessibilityLabel("Playhead")
        keptLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        keptLabel.textColor = .secondaryLabelColor
        keptLabel.lineBreakMode = .byTruncatingTail
        keptLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        zoomSlider.target = self
        zoomSlider.action = #selector(zoomChanged(_:))
        zoomSlider.controlSize = .small
        zoomSlider.setAccessibilityLabel("Timeline zoom")
        zoomSlider.widthAnchor.constraint(equalToConstant: 110).isActive = true
        let zoomOut = makeButton("minus.magnifyingglass", label: "Zoom Out of the Timeline", command: .zoomTimelineOut)
        let zoomIn = makeButton("plus.magnifyingglass", label: "Zoom Into the Timeline", command: .zoomTimelineIn)
        let transport = NSStackView(views: [
            makeButton("backward.end.fill", label: "Go to Start", command: .goToStart),
            makeButton("backward.fill", label: "Play Backward (J)", command: .reverse),
            playButton,
            makeButton("forward.fill", label: "Play Forward (L)", command: .forward),
        ])
        transport.spacing = 2
        let stack = NSStackView(views: [transport, timeLabel, keptLabel, NSView(), zoomOut, zoomSlider, zoomIn])
        stack.spacing = 10
        stack.setCustomSpacing(4, after: zoomOut)
        stack.setCustomSpacing(4, after: zoomSlider)
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 10, bottom: 4, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Shows the playhead at `time` of `duration`, whether the movie plays, and the kept range.
    func update(time: Double, duration: Double, isPlaying: Bool, range: ClosedRange<Double>, isTrimmed: Bool) {
        timeLabel.stringValue = "\(Timecode.string(time)) / \(Timecode.string(duration))"
        timeLabel.setAccessibilityValue("\(Timecode.spoken(time)) of \(Timecode.spoken(duration))")
        if showsPause != isPlaying {
            showsPause = isPlaying
            let title = isPlaying ? "Pause" : "Play"
            playButton.image = NSImage(systemSymbolName: isPlaying ? "pause.fill" : "play.fill", accessibilityDescription: title)
            playButton.toolTip = "\(title) (Space)"
            playButton.setAccessibilityLabel(title)
        }
        let kept = "\(Timecode.string(range.lowerBound))–\(Timecode.string(range.upperBound))"
        keptLabel.stringValue = isTrimmed ? "Keeps \(kept) (\(Timecode.string(range.upperBound - range.lowerBound)))" : ""
    }

    func setZoomFraction(_ fraction: Double) {
        zoomSlider.doubleValue = fraction
    }

    @objc private func zoomChanged(_ sender: NSSlider) {
        onZoom?(sender.doubleValue)
    }

    private func makeButton(_ symbol: String, label: String, command: VideoEditorCommand) -> NSButton {
        let button = CommandButton(command: command) { [weak self] command in
            self?.onCommand?(command)
        }
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        button.toolTip = label
        button.setAccessibilityLabel(label)
        return button
    }
}
