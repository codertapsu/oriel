import AppKit
import AVFoundation
import AVKit
import OrielCore
import os
import SharedUI

/// The window shown after a recording is saved (PLAN §7.4): it plays the movie and offers Trim, Export GIF,
/// Export CFR, Show in Finder and Copy. Trimming uses `AVPlayerView`'s trimming UI and a passthrough export that
/// replaces the file in place.
final class FinishedRecordingPanel: NSObject, NSWindowDelegate {
    /// Called when the window has closed.
    var onClose: (() -> Void)?

    /// The movie shown. Trimming replaces the file at this URL.
    let movie: URL
    private let frameRate: Int
    private let settings: SettingsStore
    private let window: NSPanel
    private let player: AVPlayer
    private let playerView = AVPlayerView()
    private let spinner = NSProgressIndicator()
    private let status = NSTextField(labelWithString: "")
    private var buttons: [NSButton] = []
    private var job: Task<Void, Never>?
    private let log = Log.logger("recording")

    /// `frameRate` is what "Export CFR" converts to; `videoSize` (pixels) sets the window's aspect ratio. The GIF
    /// options are read from `settings` when the GIF is made.
    init(movie: URL, frameRate: Int, videoSize: CGSize, settings: SettingsStore) {
        self.movie = movie
        self.frameRate = frameRate
        self.settings = settings
        player = AVPlayer(url: movie)
        window = NSPanel(
            contentRect: CGRect(origin: .zero, size: Self.contentSize(for: videoSize)),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        super.init()
        configureWindow()
    }

    /// Brings Oriel forward and shows the window centred on `screen`.
    func show(on screen: NSScreen?) {
        if let visible = (screen ?? NSScreen.main)?.visibleFrame {
            let size = window.frame.size
            window.setFrameOrigin(CGPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2))
        }
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
        // Activation is cooperative and can be declined; the window still comes to the front.
        window.orderFrontRegardless()
    }

    func windowWillClose(_: Notification) {
        job?.cancel()
        player.pause()
        playerView.player = nil
        // The owner releases this object in `onClose`; doing that after AppKit has finished closing the window
        // keeps the window alive for the rest of its close.
        let onClose = onClose
        Task { onClose?() }
    }

    /// The trimmed range, or nil when the user kept the whole movie. Unset ends mean the start and the end.
    nonisolated static func trimRange(start: CMTime, end: CMTime, duration: CMTime) -> CMTimeRange? {
        let lower = start.isNumeric ? max(start, .zero) : .zero
        let upper = end.isNumeric ? min(end, duration) : duration
        guard upper > lower else { return nil }
        let range = CMTimeRange(start: lower, end: upper)
        return range == CMTimeRange(start: .zero, duration: duration) ? nil : range
    }

    private static func contentSize(for videoSize: CGSize) -> CGSize {
        let aspect = videoSize.width > 0 && videoSize.height > 0 ? videoSize.height / videoSize.width : 9.0 / 16.0
        let width: CGFloat = 720
        return CGSize(width: width, height: min(max(width * aspect, 240), 560) + 48)
    }

    private func configureWindow() {
        window.title = movie.lastPathComponent
        window.representedURL = movie
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        // Wide enough for the toolbar's five buttons.
        window.contentMinSize = CGSize(width: 640, height: 320)
        window.delegate = self

        playerView.player = player
        playerView.controlsStyle = .inline
        playerView.showsSharingServiceButton = true
        playerView.showsFullScreenToggleButton = true
        playerView.translatesAutoresizingMaskIntoConstraints = false

        buttons = [
            makeButton("Trim", symbol: "scissors", action: #selector(trim(_:))),
            makeButton("Export GIF", symbol: "photo.on.rectangle.angled", action: #selector(exportGIF(_:))),
            makeButton("Export CFR", symbol: "film", action: #selector(exportConstantFrameRate(_:))),
            makeButton("Show in Finder", symbol: "folder", action: #selector(reveal(_:))),
            makeButton("Copy", symbol: "doc.on.doc", action: #selector(copyFile(_:))),
        ]
        buttons[2].toolTip = "Re-encode at a constant \(frameRate) fps for video editors"
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        status.textColor = .secondaryLabelColor
        status.lineBreakMode = .byTruncatingTail
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let toolbar = NSStackView(views: buttons + [status, spinner])
        toolbar.spacing = 8
        toolbar.setHuggingPriority(.defaultLow, for: .horizontal)
        toolbar.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(playerView)
        content.addSubview(toolbar)
        NSLayoutConstraint.activate([
            playerView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            playerView.topAnchor.constraint(equalTo: content.topAnchor),
            toolbar.topAnchor.constraint(equalTo: playerView.bottomAnchor),
            toolbar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        window.contentView = content
    }

    private func makeButton(_ title: String, symbol: String, action: Selector) -> NSButton {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: title) ?? NSImage()
        let button = NSButton(title: title, image: image, target: self, action: action)
        button.imagePosition = .imageLeading
        return button
    }

    @objc private func trim(_: Any?) {
        guard job == nil, playerView.canBeginTrimming else { return }
        job = Task { [weak self] in
            await self?.runTrim()
            self?.job = nil
        }
    }

    private func runTrim() async {
        guard await playerView.beginTrimming() == .okButton, let item = player.currentItem,
              let range = Self.trimRange(start: item.reversePlaybackEndTime, end: item.forwardPlaybackEndTime, duration: item.duration)
        else {
            return
        }
        setBusy("Trimming…")
        let movie = movie
        let trimmed = RecordingFileNamer.sibling(of: movie, suffix: " (trimming)", pathExtension: "mp4")
        do {
            try await MovieExporter.trim(movie, range: range, to: trimmed)
            _ = try FileManager.default.replaceItemAt(movie, withItemAt: trimmed)
            player.replaceCurrentItem(with: AVPlayerItem(url: movie))
            setBusy(nil)
            Toast.show("Trimmed", symbol: "scissors")
        } catch {
            try? FileManager.default.removeItem(at: trimmed)
            setBusy(nil)
            report(error)
        }
    }

    @objc private func exportGIF(_: Any?) {
        let options = RecordingOptions(settings: settings).gif
        run("Making the GIF…") { [movie] in
            let output = RecordingFileNamer.sibling(of: movie, pathExtension: "gif")
            try await GIFExporter.export(movie, to: output, options: options)
            return output
        }
    }

    @objc private func exportConstantFrameRate(_: Any?) {
        let frameRate = frameRate
        run("Converting to \(frameRate) fps…") { [movie] in
            let output = RecordingFileNamer.sibling(of: movie, suffix: " (CFR)", pathExtension: "mp4")
            try await ConstantFrameRateExporter.export(movie, to: output, frameRate: frameRate)
            return output
        }
    }

    @objc private func reveal(_: Any?) {
        NSWorkspace.shared.activateFileViewerSelecting([movie])
    }

    @objc private func copyFile(_: Any?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if pasteboard.writeObjects([movie as NSURL]) {
            Toast.show("Copied", symbol: "doc.on.doc")
        }
    }

    /// Runs an export, then shows its file in Finder.
    private func run(_ message: String, _ work: @escaping @Sendable () async throws -> URL) {
        guard job == nil else { return }
        setBusy(message)
        job = Task { [weak self] in
            do {
                let file = try await work()
                self?.setBusy(nil)
                NSWorkspace.shared.activateFileViewerSelecting([file])
                Toast.show("Saved \(file.lastPathComponent)", symbol: "checkmark.circle")
            } catch is CancellationError {
                // The window closed.
                self?.setBusy(nil)
            } catch {
                self?.setBusy(nil)
                self?.report(error)
            }
            self?.job = nil
        }
    }

    private func setBusy(_ message: String?) {
        status.stringValue = message ?? ""
        for button in buttons {
            button.isEnabled = message == nil
        }
        if message == nil {
            spinner.stopAnimation(nil)
        } else {
            spinner.startAnimation(nil)
        }
    }

    private func report(_ error: any Error) {
        log.error("finished-recording action failed: \(error.localizedDescription, privacy: .public)")
        let message = error.localizedDescription
        status.stringValue = message
        Toast.show(message, symbol: "exclamationmark.triangle")
    }
}
