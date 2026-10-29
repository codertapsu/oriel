import AppIntents
import SharedUI

/// Take a Screenshot (PLAN §7.17): an area the user selects, a window they click, or the whole display under the
/// pointer, returned as a PNG for the next action; the capture also runs Oriel's after-capture action.
struct CaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Take a Screenshot"
    static let description = IntentDescription(
        "Captures an area you select, a window you click or the screen, and passes the image to the next action.",
        categoryName: "Capture"
    )

    @Parameter(title: "Mode", default: .area)
    var mode: CaptureModeOption

    static var parameterSummary: some ParameterSummary {
        Summary("Capture \(\.$mode)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let capture = try IntentContext.require().hub.capture
        let result = switch mode {
        case .area: await capture.capture(.area)
        case .window: await capture.capture(.window)
        case .screen: try await capture.captureScreen(displayID: nil)
        }
        guard let result else { throw OrielIntentError.cancelled }
        guard let png = ImageFile.data(for: result.image, format: .png, scale: result.scale) else {
            throw OrielIntentError.failed("The screenshot could not be encoded.")
        }
        return .result(value: IntentFile(data: png, filename: "Screenshot.png", type: .png))
    }
}
