/// How Window Tiling reaches the user: a beep, a toast, a VoiceOver announcement and the Accessibility notice. The app
/// uses `SystemTilingFeedback`; tests record the calls instead of showing anything.
protocol TilingFeedback: AnyObject {
    func respond(_ response: TilingResponse)
    /// Explains that Accessibility is missing and offers its pane in System Settings.
    func askForAccessibility(paneName: String, openSettings: @escaping @MainActor () -> Void)
    /// Takes down anything still showing, when the tool is turned off.
    func dismiss()
}
