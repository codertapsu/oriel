import SwiftUI

/// Hosts the AppKit drag source in the SwiftUI action bar.
struct DragOutHandle: NSViewRepresentable {
    let makePayload: () -> DragPayload?
    let onDelivered: () -> Void

    func makeNSView(context _: Context) -> DragOutView {
        let view = DragOutView(frame: .zero)
        view.makePayload = makePayload
        view.onDelivered = onDelivered
        return view
    }

    func updateNSView(_ view: DragOutView, context _: Context) {
        view.makePayload = makePayload
        view.onDelivered = onDelivered
    }
}
