/// What the Quick Access Overlay (and history, and pins) can ask the rest of the app to do with a capture.
/// The app implements it and hands it to Capture, so Capture never links the editor, translation or upload.
@MainActor
public protocol CaptureActionHandling: AnyObject {
    func annotate(_ capture: CaptureResult)
    func translate(_ capture: CaptureResult)
    func upload(_ capture: CaptureResult)
}
