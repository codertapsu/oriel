import AppKit
import OrielCore
import SharedUI

/// The status menu's Pinned submenu (PLAN §10.1, §17), and the commands of one pin, which its context menu shows too.
/// Every pinned capture is listed oldest first with a small thumbnail and its state, and has a submenu: Bring to Front
/// and the pin's own commands, so a click-through pin can always be switched back from here. Then Stop Click-Through
/// on All Pins, while any pin lets clicks through, and Close All Pins.
enum PinsMenu {
    /// One pinned capture as the menu shows it.
    struct Entry {
        let result: CaptureResult
        let state: PinState
    }

    /// The thumbnail fits in this many points.
    nonisolated static let thumbnailSize = CGSize(width: 36, height: 18)

    /// Nil while nothing is pinned.
    static func make(
        for entries: [Entry],
        perform: @escaping @MainActor @Sendable (UUID, PinCommand) -> Void,
        stopClickThrough: @escaping @MainActor @Sendable () -> Void,
        closeAll: @escaping @MainActor @Sendable () -> Void
    ) -> NSMenu? {
        guard !entries.isEmpty else { return nil }
        let menu = NSMenu(title: "Pinned")
        for entry in entries {
            let id = entry.result.id
            let item = NSMenuItem(
                title: title(for: entry.result, time: entry.result.date.formatted(date: .omitted, time: .shortened)),
                action: nil,
                keyEquivalent: ""
            )
            item.image = thumbnail(of: entry.result.image)
            item.subtitle = subtitle(for: entry.state)
            let submenu = NSMenu(title: item.title)
            submenu.addItem(ActionMenuItem("Bring to Front", symbol: "macwindow.on.rectangle") { perform(id, .bringToFront) })
            submenu.addItem(.separator())
            for command in commandItems(for: entry.state, perform: { perform(id, $0) }) {
                submenu.addItem(command)
            }
            item.submenu = submenu
            menu.addItem(item)
        }
        menu.addItem(.separator())
        if entries.contains(where: \.state.isClickThrough) {
            menu.addItem(ActionMenuItem("Stop Click-Through on All Pins", symbol: "cursorarrow.click", handler: stopClickThrough))
        }
        menu.addItem(ActionMenuItem("Close All Pins", symbol: "pin.slash", handler: closeAll))
        return menu
    }

    /// One pin's commands: the opacity slider, the toggles, zoom, copy, save, annotate and close. The key equivalents
    /// are what the pin answers to while it is the window in front.
    static func commandItems(for state: PinState, perform: @escaping @MainActor @Sendable (PinCommand) -> Void) -> [NSMenuItem] {
        [
            PinOpacitySlider.menuItem(opacity: state.opacity) { perform(.setOpacity($0)) },
            pro(toggle("Click-Through", symbol: "cursorarrow.rays", isOn: state.isClickThrough) { perform(.toggleClickThrough) }),
            pro(toggle("Lock Position", symbol: "lock", isOn: state.isLocked) { perform(.toggleLock) }),
            toggle("Border and Shadow", symbol: "square.on.square.dashed", isOn: state.showsBorder) { perform(.toggleBorder) },
            .separator(),
            ActionMenuItem("Zoom In", symbol: "plus.magnifyingglass", key: "+") { perform(.zoomIn) },
            ActionMenuItem("Zoom Out", symbol: "minus.magnifyingglass", key: "-") { perform(.zoomOut) },
            ActionMenuItem("Actual Size", symbol: "1.magnifyingglass", key: "0") { perform(.actualSize) },
            .separator(),
            ActionMenuItem("Copy", symbol: "doc.on.doc", key: "c") { perform(.copy) },
            ActionMenuItem("Save", symbol: "square.and.arrow.down", key: "s") { perform(.save) },
            ActionMenuItem("Annotate", symbol: "pencil.tip.crop.circle") { perform(.annotate) },
            .separator(),
            ActionMenuItem("Close", symbol: "xmark", key: "w") { perform(.close) },
        ]
    }

    /// Marks a pin option that needs Oriel Pro (PLAN §19).
    private static func pro(_ item: NSMenuItem) -> NSMenuItem {
        ProMenuBadge.apply(.pinTools, to: item)
        return item
    }

    /// "Safari · 14:02": the app the capture came from (else its window, else how it was made) and when.
    nonisolated static func title(for result: CaptureResult, time: String) -> String {
        let source = [result.appName, result.windowTitle].compactMap(\.self).first { !$0.isEmpty }
        return "\(source ?? name(of: result.kind)) · \(time)"
    }

    /// "Click-through · Locked · 60 %": what is not as it was when pinned; nil when nothing is.
    nonisolated static func subtitle(for state: PinState) -> String? {
        var parts: [String] = []
        if state.isClickThrough {
            parts.append("Click-through")
        }
        if state.isLocked {
            parts.append("Locked")
        }
        if state.opacityPercent < 100 {
            parts.append("\(state.opacityPercent) %")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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

    private static func toggle(
        _ title: String,
        symbol: String,
        isOn: Bool,
        handler: @escaping @MainActor @Sendable () -> Void
    ) -> NSMenuItem {
        let item = ActionMenuItem(title, symbol: symbol, handler: handler)
        item.state = isOn ? .on : .off
        return item
    }

    private static func thumbnail(of image: CGImage) -> NSImage {
        NSImage(cgImage: image, size: fittedSize(of: CGSize(width: image.width, height: image.height)))
    }
}
