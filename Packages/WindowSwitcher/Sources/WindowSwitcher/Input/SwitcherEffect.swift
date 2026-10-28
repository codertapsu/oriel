/// What the controller has to do after a transition. Indexes refer to the items the controller last passed to
/// `SwitcherStateMachine.setItems`.
nonisolated enum SwitcherEffect: Sendable, Equatable {
    /// Open the panel for shortcut `shortcutIndex`; the controller answers with `setItems`.
    case show(shortcutIndex: Int)
    case select(Int)
    /// The search text changed; the controller re-ranks and calls `setItems` again.
    case search(String)
    /// Close the panel and focus item `index`.
    case commit(index: Int)
    /// Close the panel without switching.
    case cancel
    /// Close, minimize or toggle full screen of item `index`; the panel stays open.
    case act(WindowAction, index: Int)
    /// Quit the app of item `index`.
    case quitApp(index: Int)
}
