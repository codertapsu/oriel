import AppKit

/// The video editor's inspector (PLAN §17), beside the preview: Auto Zoom and the selected zoom, then the
/// chapters. Every control has a keyboard equivalent or a plain button, so nothing needs the timeline's mouse.
final class VideoEditorInspector: NSView {
    static let width: CGFloat = 300

    /// Asked to show a time, after a chapter was chosen in the list.
    var onSeek: ((Double) -> Void)?
    /// The playhead's time, for the buttons that add at the playhead.
    var currentTime: () -> Double = { 0 }
    /// Auto Zoom's settings changed.
    var onAutoZoomSettings: ((AutoZoomSettings) -> Void)?
    /// Copy for YouTube and Save Timestamps.
    var onCopyTimestamps: (() -> Void)?
    var onSaveTimestamps: (() -> Void)?
    /// Asked for a picture of the frame at a time, for the focus picker. Setting it asks again for the frame shown.
    var onNeedsFocusFrame: ((Double) -> Void)? {
        didSet {
            focusFrameTime = nil
            updateSelectedZoom()
        }
    }

    let session: VideoEditorSession
    let chapterTable = NSTableView()

    private let autoZoomButton = NSButton(title: "Auto Zoom", target: nil, action: nil)
    private let clicksNote = NSTextField(wrappingLabelWithString: "")
    private let levelSlider = NSSlider(
        value: 2,
        minValue: ZoomSegment.scales.lowerBound,
        maxValue: ZoomSegment.scales.upperBound,
        target: nil,
        action: nil
    )
    private let levelLabel = NSTextField(labelWithString: "")
    private let holdSlider = NSSlider(
        value: 1.5,
        minValue: AutoZoomSettings.holds.lowerBound,
        maxValue: AutoZoomSettings.holds.upperBound,
        target: nil,
        action: nil
    )
    private let holdLabel = NSTextField(labelWithString: "")
    private let addZoomButton = NSButton(title: "Add Zoom", target: nil, action: nil)
    private let removeZoomsButton = NSButton(title: "Remove All", target: nil, action: nil)

    private let selectedBox = NSStackView()
    private let startStepper = NSStepper()
    private let startLabel = NSTextField(labelWithString: "")
    private let endStepper = NSStepper()
    private let endLabel = NSTextField(labelWithString: "")
    private let selectedLevelSlider = NSSlider(
        value: 2,
        minValue: ZoomSegment.scales.lowerBound,
        maxValue: ZoomSegment.scales.upperBound,
        target: nil,
        action: nil
    )
    private let selectedLevelLabel = NSTextField(labelWithString: "")
    let focusPicker = FocusPickerView(frame: .zero)
    private let focusNote = NSTextField(wrappingLabelWithString: "")
    private let deleteZoomButton = NSButton(title: "Delete Zoom", target: nil, action: nil)

    let addChapterButton = NSButton()
    let removeChapterButton = NSButton()
    let copyTimestampsButton = NSButton(title: "Copy for YouTube", target: nil, action: nil)
    let saveTimestampsButton = NSButton(title: "Save as Text…", target: nil, action: nil)
    let chapterNote = NSTextField(wrappingLabelWithString: "")
    /// The focus point the picker edits, and the frame time its picture shows.
    private var focusTarget: (segment: UUID, index: Int)?
    var focusFrameTime: Double?

    init(session: VideoEditorSession) {
        self.session = session
        super.init(frame: CGRect(x: 0, y: 0, width: Self.width, height: 600))
        build()
        update()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Layout

    private func build() {
        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 10
        content.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 16, right: 16)
        content.translatesAutoresizingMaskIntoConstraints = false
        for view in zoomSection() + [Self.separator()] + chapterSection() {
            content.addArrangedSubview(view)
            if !(view is NSButton) {
                view.widthAnchor.constraint(equalTo: content.widthAnchor, constant: -32).isActive = true
            }
        }
        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(content)
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.documentView = document
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            document.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            document.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            document.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            content.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            content.topAnchor.constraint(equalTo: document.topAnchor),
            content.bottomAnchor.constraint(equalTo: document.bottomAnchor),
        ])
    }

    private func zoomSection() -> [NSView] {
        configure(autoZoomButton, symbol: "sparkles", action: #selector(autoZoom(_:)))
        autoZoomButton.keyEquivalent = ""
        Self.style(note: clicksNote)
        configure(slider: levelSlider, label: levelLabel, accessibility: "Auto Zoom level", action: #selector(autoZoomSettingsChanged(_:)))
        configure(slider: holdSlider, label: holdLabel, accessibility: "Auto Zoom hold", action: #selector(autoZoomSettingsChanged(_:)))
        configure(addZoomButton, symbol: "plus.magnifyingglass", action: #selector(addZoom(_:)))
        addZoomButton.toolTip = "Add a zoom at the playhead (Z)"
        configure(removeZoomsButton, symbol: "xmark.circle", action: #selector(removeZooms(_:)))

        selectedBox.orientation = .vertical
        selectedBox.alignment = .leading
        selectedBox.spacing = 8
        for (stepper, label, name) in [(startStepper, startLabel, "Zoom start"), (endStepper, endLabel, "Zoom end")] {
            stepper.minValue = 0
            stepper.maxValue = session.duration
            stepper.increment = 0.1
            stepper.valueWraps = false
            stepper.autorepeat = true
            stepper.controlSize = .small
            stepper.target = self
            stepper.action = #selector(rangeStepped(_:))
            stepper.setAccessibilityLabel(name)
            label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            label.textColor = .secondaryLabelColor
        }
        configure(
            slider: selectedLevelSlider,
            label: selectedLevelLabel,
            accessibility: "Zoom level",
            action: #selector(selectedLevelChanged(_:))
        )
        focusPicker.onChange = { [weak self] point in
            self?.focusChanged(point)
        }
        Self.style(note: focusNote)
        configure(deleteZoomButton, symbol: "trash", action: #selector(deleteZoom(_:)))
        for view in [
            Self.subheading("Selected Zoom"),
            Self.row("Start", startLabel, startStepper),
            Self.row("End", endLabel, endStepper),
            Self.row("Level", selectedLevelSlider, selectedLevelLabel),
            focusPicker,
            focusNote,
            deleteZoomButton,
        ] {
            selectedBox.addArrangedSubview(view)
            if !(view is NSButton) {
                view.widthAnchor.constraint(equalTo: selectedBox.widthAnchor).isActive = true
            }
        }
        let zoomButtons = NSStackView(views: [addZoomButton, removeZoomsButton])
        zoomButtons.spacing = 8
        return [
            Self.heading("Zoom"),
            autoZoomButton,
            clicksNote,
            Self.row("Level", levelSlider, levelLabel),
            Self.row("Hold", holdSlider, holdLabel),
            zoomButtons,
            selectedBox,
        ]
    }

    // MARK: Updating

    /// Shows the session as it is now.
    func update() {
        let hasClicks = session.clicks != nil
        autoZoomButton.isEnabled = hasClicks
        clicksNote.stringValue = if let clicks = session.clicks {
            "\(clicks.clicks.count) click\(clicks.clicks.count == 1 ? " was" : "s were") saved with this recording. "
                + "Auto Zoom zooms in on them, panning between nearby ones."
        } else {
            "No clicks were saved with this movie. Auto Zoom works on recordings made with Remember clicks for Auto "
                + "Zoom on; you can still add zooms yourself."
        }
        levelSlider.doubleValue = session.autoZoom.level
        levelLabel.stringValue = TimelineView.scaleLabel(session.autoZoom.level)
        holdSlider.doubleValue = session.autoZoom.hold
        holdLabel.stringValue = String(format: "%.1f s", session.autoZoom.hold)
        removeZoomsButton.isEnabled = !session.edit.zoomSegments.isEmpty
        updateSelectedZoom()
        updateChapters()
    }

    /// The playhead moved: in a zoom that pans, the focus picker follows the focus point being shown.
    func playheadDidMove() {
        guard let segment = session.selectedZoom, segment.focus.count > 1 else { return }
        let time = min(max(currentTime(), segment.start), segment.end)
        if focusTarget?.segment != segment.id || focusTarget?.index != segment.focusIndex(at: time) {
            updateSelectedZoom()
        }
    }

    private func updateSelectedZoom() {
        guard let segment = session.selectedZoom else {
            selectedBox.isHidden = true
            focusTarget = nil
            return
        }
        selectedBox.isHidden = false
        startLabel.stringValue = Timecode.string(segment.start)
        startStepper.doubleValue = segment.start
        startStepper.setAccessibilityValue(Timecode.spoken(segment.start))
        endLabel.stringValue = Timecode.string(segment.end)
        endStepper.doubleValue = segment.end
        endStepper.setAccessibilityValue(Timecode.spoken(segment.end))
        selectedLevelSlider.doubleValue = segment.scale
        selectedLevelLabel.stringValue = TimelineView.scaleLabel(segment.scale)
        let time = min(max(currentTime(), segment.start), segment.end)
        let index = segment.focus.count > 1 ? segment.focusIndex(at: time) : 0
        let focus = segment.focus[index]
        focusTarget = (segment.id, index)
        focusPicker.frameSize = session.info.size
        focusPicker.show(scale: segment.scale, center: focus.point)
        focusNote.stringValue = segment.focus.count > 1
            ? "Focus \(index + 1) of \(segment.focus.count), from \(Timecode.string(focus.time)). Move the playhead to edit another."
            : "Drag the area to choose where the zoom looks."
        if focusFrameTime != focus.time {
            focusFrameTime = focus.time
            focusPicker.image = nil
            onNeedsFocusFrame?(focus.time)
        }
    }

    // MARK: Actions

    @objc private func autoZoom(_: Any?) {
        session.applyAutoZoom()
    }

    @objc private func autoZoomSettingsChanged(_: Any?) {
        let settings = AutoZoomSettings(
            level: (levelSlider.doubleValue * 10).rounded() / 10,
            hold: (holdSlider.doubleValue * 10).rounded() / 10
        )
        session.autoZoom = settings
        levelLabel.stringValue = TimelineView.scaleLabel(settings.level)
        holdLabel.stringValue = String(format: "%.1f s", settings.hold)
        onAutoZoomSettings?(settings)
    }

    @objc private func addZoom(_: Any?) {
        session.addZoom(at: currentTime())
    }

    @objc private func removeZooms(_: Any?) {
        session.removeAllZooms()
    }

    @objc private func selectedLevelChanged(_ sender: NSSlider) {
        guard let segment = session.selectedZoom else { return }
        session.setZoomScale(segment.id, scale: (sender.doubleValue * 10).rounded() / 10)
    }

    /// The start or end stepper moved by a tenth of a second.
    @objc private func rangeStepped(_ sender: NSStepper) {
        guard let segment = session.selectedZoom else { return }
        if sender === startStepper {
            session.commit("Change Zoom", coalescing: "start-\(segment.id)") {
                $0.resizeZoom(segment.id, start: sender.doubleValue, duration: session.duration)
            }
        } else {
            session.commit("Change Zoom", coalescing: "end-\(segment.id)") {
                $0.resizeZoom(segment.id, end: sender.doubleValue, duration: session.duration)
            }
        }
    }

    private func focusChanged(_ point: CGPoint) {
        guard let focusTarget else { return }
        session.setZoomFocus(focusTarget.segment, focusIndex: focusTarget.index, point: point)
    }

    @objc private func deleteZoom(_: Any?) {
        session.deleteSelection()
    }

    @objc func copyTimestamps(_: Any?) {
        onCopyTimestamps?()
    }

    @objc func saveTimestamps(_: Any?) {
        onSaveTimestamps?()
    }

    // MARK: Building blocks

    func configure(_ button: NSButton, symbol: String, action: Selector) {
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button.imagePosition = .imageLeading
        button.bezelStyle = .push
        button.controlSize = .regular
        button.target = self
        button.action = action
    }

    private func configure(slider: NSSlider, label: NSTextField, accessibility: String, action: Selector) {
        slider.target = self
        slider.action = action
        slider.isContinuous = true
        slider.controlSize = .small
        slider.setAccessibilityLabel(accessibility)
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        label.widthAnchor.constraint(equalToConstant: 42).isActive = true
    }

    static func heading(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        label.setAccessibilityRole(.staticText)
        return label
    }

    static func subheading(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    static func style(note: NSTextField) {
        note.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = .secondaryLabelColor
        note.preferredMaxLayoutWidth = width - 32
    }

    /// `Title  [control]  value`, the title in a fixed column.
    static func row(_ title: String, _ control: NSView, _ value: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.textColor = .secondaryLabelColor
        label.widthAnchor.constraint(equalToConstant: 44).isActive = true
        let row = NSStackView(views: [label, control, value])
        row.spacing = 8
        return row
    }

    static func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }
}
