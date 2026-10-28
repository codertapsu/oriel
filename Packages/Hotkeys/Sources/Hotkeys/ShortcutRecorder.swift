import OrielCore
import SwiftUI

/// SwiftUI wrapper of `ShortcutRecorderView`, for the Settings panes.
public struct ShortcutRecorder: NSViewRepresentable {
    @Binding private var combo: KeyCombo?
    private let allowed: Set<KeyCombo>
    private let inUse: [KeyCombo: String]

    public init(combo: Binding<KeyCombo?>, allowed: Set<KeyCombo> = [], inUse: [KeyCombo: String] = [:]) {
        _combo = combo
        self.allowed = allowed
        self.inUse = inUse
    }

    public func makeNSView(context _: Context) -> ShortcutRecorderView {
        let view = ShortcutRecorderView()
        view.setContentHuggingPriority(.required, for: .vertical)
        return view
    }

    public func updateNSView(_ view: ShortcutRecorderView, context _: Context) {
        view.combo = combo
        view.allowed = allowed
        view.inUse = inUse
        view.onChange = { combo = $0 }
    }
}
