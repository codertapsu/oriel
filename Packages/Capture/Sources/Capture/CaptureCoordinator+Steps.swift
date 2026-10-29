import AppKit
import OrielCore
import SharedUI

/// Step Capture (PLAN §17): numbered step sequences for guides and bug reports. While a session runs, every capture,
/// in any mode, becomes its next step instead of opening Quick Access; Finish opens the sequence window, which edits
/// and exports the steps and hands one to the editor through `CaptureActionHandling.annotate`.
extension CaptureCoordinator {
    var isStepCaptureActive: Bool {
        stepCapture != nil
    }

    /// The Step Capture command: starts a session, or finishes the one running.
    func toggleStepCapture() {
        if isStepCaptureActive {
            finishStepCapture()
        } else {
            startStepCapture()
        }
    }

    func startStepCapture() {
        guard stepCapture == nil else { return }
        let controller = StepCaptureController(settings: settings)
        controller.onAddStep = { [weak self] in
            Task { await self?.capture(.area) }
        }
        controller.onFinish = { [weak self] in self?.finishStepCapture() }
        controller.onCancel = { [weak self] in self?.cancelStepCapture() }
        controller.windowsChanged = { [weak self] in self?.cache.invalidate() }
        stepCapture = controller
        controller.start()
    }

    /// Ends the session and opens its steps; says so when there were none.
    func finishStepCapture() {
        guard let controller = stepCapture else { return }
        stepCapture = nil
        guard let document = controller.finish() else {
            Toast.show("No steps were captured", symbol: "list.number")
            return
        }
        openSequence(document)
    }

    /// Ends the session without keeping its steps, after asking when there are any.
    func cancelStepCapture() {
        guard let controller = stepCapture, controller.confirmCancel() else { return }
        stepCapture = nil
        controller.cancel()
    }

    /// A capture for the sequence window (Retake, Add Step): the overlay as usual, with the result going back to the
    /// window rather than to the after-capture action, history or the clipboard.
    func captureForSequence(_ mode: CaptureMode) async -> CaptureResult? {
        guard !isBusy else { return nil }
        isBusy = true
        defer { isBusy = false }
        guard await ensureScreenRecording() else { return nil }
        do {
            guard let captured = try await interactiveCapture(mode) else { return nil }
            if settings[CaptureSettings.playsSound] {
                CaptureFeedback.playShutter()
            }
            return captured.result
        } catch {
            log.error("Capture for a step failed: \(error.localizedDescription, privacy: .private)")
            PermissionPrompt.show(error)
            return nil
        }
    }

    private func openSequence(_ document: StepDocument) {
        let window = StepSequenceWindowController(document: document, canAnnotate: actions != nil)
        window.onRetake = { [weak self, weak window] step in
            Task {
                guard let result = await self?.captureForSequence(step.retakeMode) else { return }
                window?.replaceImage(of: step.id, with: result.image, scale: result.scale)
                window?.show()
            }
        }
        window.onAddStep = { [weak self, weak window] in
            Task {
                guard let result = await self?.captureForSequence(.area) else { return }
                window?.append(result)
                window?.show()
            }
        }
        window.onAnnotate = { [weak self, weak document] step in
            Task { await self?.annotate(step, of: document) }
        }
        window.onClosed = { [weak self, weak window] in
            self?.stepWindows.removeAll { $0 === window }
        }
        stepWindows.append(window)
        window.show()
    }

    /// Opens the editor on the step's image, click marker included; the result comes back by dragging it onto the
    /// step or pasting it there, since the editor hands nothing back.
    private func annotate(_ step: Step, of document: StepDocument?) async {
        guard let actions, let document, let image = await document.image(of: step) else { return }
        let marked = step.click.flatMap { StepImageRenderer.marked(image, at: $0, scale: step.scale) } ?? image
        let number = document.sequence.number(of: step.id) ?? 1
        actions.annotate(CaptureResult(
            image: marked,
            kind: step.kind,
            rect: .zero,
            scale: step.scale,
            date: step.date,
            windowTitle: step.windowTitle,
            appName: step.appName
        ))
        Toast.show(
            "To use the annotated image, drag it onto step \(number) or copy it and paste it there",
            symbol: "pencil.tip.crop.circle",
            duration: .seconds(4)
        )
    }
}
