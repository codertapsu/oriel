import AppKit
import OrielCore
import SharedUI

/// The status menu's Pinned submenu (PLAN §10.1): every pinned capture, oldest first, with a small thumbnail, to bring
/// it to the front; then Close All Pins.
enum PinsMenu {
    /// The thumbnail fits in this many points.
    nonisolated static let thumbnailSize = CGSize(width: 36, height: 18)

    /// Nil while nothing is pinned.
    static func make(
        for results: [CaptureResult],
        reveal: @escaping @MainActor @Sendable (UUID) -> Void,
        closeAll: @escaping @MainActor @Sendable () -> Void
    ) -> NSMenu? {
        guard !results.isEmpty else { return nil }
        let menu = NSMenu(title: "Pinned")
        for result in results {
            let id = result.id
            let item = ActionMenuItem(title(for: result, time: result.date.formatted(date: .omitted, time: .shortened))) {
                reveal(id)
            }
            item.image = thumbnail(of: result.image)
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("Close All Pins", symbol: "pin.slash", handler: closeAll))
        return menu
    }

    /// "Safari · 14:02": the app the capture came from (else its window, else how it was made) and when.
    nonisolated static func title(for result: CaptureResult, time: String) -> String {
        let source = [result.appName, result.windowTitle].compactMap(\.self).first { !$0.isEmpty }
        return "\(source ?? name(of: result.kind)) · \(time)"
    }

    nonisolated static func name(of kind: CaptureKind) -> String {
        switch kind {
        case .area: "Area"
        case .window: "Window"
        case .screen: "Screen"
        case .scrolling: "Scrolling Capture"
        case .imported: "Image"
        }
    }

    /// `image` scaled to fit `thumbnailSize`, keeping its shape.
    nonisolated static func fittedSize(of image: CGSize) -> CGSize {
        guard image.width > 0, image.height > 0 else { return thumbnailSize }
        let factor = min(thumbnailSize.width / image.width, thumbnailSize.height / image.height)
        return CGSize(width: max(1, (image.width * factor).rounded()), height: max(1, (image.height * factor).rounded()))
    }

    private static func thumbnail(of image: CGImage) -> NSImage {
        NSImage(cgImage: image, size: fittedSize(of: CGSize(width: image.width, height: image.height)))
    }
}
