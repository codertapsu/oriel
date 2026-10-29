import AppKit
import OrielCore
import SharedUI

/// A running Step Capture (PLAN §17): the session's state, its palette, the click monitor while Mark Clicks is on,
/// and the images so far. The coordinator gives it every capture taken while it runs; Finish turns it into a
/// `StepDocument` for the sequence window. Nothing of it is left once it has finished or been cancelled: no monitor,
/// no window.
final class StepCaptureController {
    var onAddStep: (() -> Void)?
    var onFinish: (() -> Void)?
    var onCancel: (() -> Void)?
    /// The palette appeared or went, which changes what captures leave out.
    var windowsChanged: (() -> Void)?

    private var session: StepSession
    private let images = StepImages()
    private let palette: StepCapturePalette
    private let clicks = ClickMonitor()
    private let settings: SettingsStore
    private let started = Date()

    init(settings: SettingsStore) {
        self.settings = settings
        let marksClicks = settings[CaptureSettings.stepsMarkClicks]
        session = StepSession(marksClicks: marksClicks)
        palette = StepCapturePalette(marksClicks: marksClicks)
        palette.onAddStep = { [weak self] in self?.onAddStep?() }
        palette.onFinish = { [weak self] in self?.onFinish?() }
        palette.onCancel = { [weak self] in self?.onCancel?() }
        palette.onHide = { [weak self] in self?.hidePalette() }
        palette.onMarksClicksChanged = { [weak self] isOn in self?.setMarksClicks(isOn) }
        clicks.onClick = { [weak self] point in self?.session.recordClick(at: point) }
    }

    var stepCount: Int {
        session.sequence.count
    }

    func start() {
        session.start(title: StepSequence.defaultTitle(at: started))
        if session.marksClicks {
            clicks.start()
        }
        palette.show()
        windowsChanged?()
    }

    /// The next step: `result` with the last click marked, when it falls inside it.
    func add(_ result: CaptureResult) {
        let click = session.takeClick().flatMap { point in
            ClickMarker.pixelPoint(
                of: point,
                in: result.rect,
                scale: result.scale,
                imageSize: CGSize(width: result.image.width, height: result.image.height)
            )
        }
        let step = Step(result: result, imageURL: images.add(result.image, scale: result.scale), click: click)
        guard let number = session.append(step) else { return }
        palette.update(count: number)
        if !palette.isVisible {
            Toast.show("Step \(number) captured", symbol: "list.number")
        }
    }

    /// Ends the session: the steps for the sequence window, or nil when none were taken.
    func finish() -> StepDocument? {
        stop()
        guard let sequence = session.finish() else {
            images.discard()
            return nil
        }
        return StepDocument(sequence: sequence, images: images, date: started)
    }

    /// Asks before throwing captured steps away; true to go ahead.
    func confirmCancel() -> Bool {
        guard session.cancelNeedsConfirmation else { return true }
        let count = session.sequence.count
        let alert = NSAlert()
        alert.messageText = count == 1 ? "Discard the step you captured?" : "Discard the \(count) steps you captured?"
        alert.informativeText = "Step Capture ends and its images are deleted. To keep them, choose Finish instead."
        alert.addButton(withTitle: "Discard Steps")
        alert.addButton(withTitle: "Keep Capturing")
        alert.buttons.first?.hasDestructiveAction = true
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Ends the session and deletes its images.
    func cancel() {
        stop()
        _ = session.cancel()
        images.discard()
    }

    private func stop() {
        clicks.stop()
        palette.close()
        windowsChanged?()
    }

    private func hidePalette() {
        palette.close()
        windowsChanged?()
        Toast.show(
            "Step Capture goes on. Choose Finish Step Capture in Oriel's menu when you are done.",
            symbol: "list.number",
            duration: .seconds(3.2)
        )
    }

    private func setMarksClicks(_ isOn: Bool) {
        settings[CaptureSettings.stepsMarkClicks] = isOn
        session.marksClicks = isOn
        if isOn {
            clicks.start()
        } else {
            clicks.stop()
        }
    }
}
