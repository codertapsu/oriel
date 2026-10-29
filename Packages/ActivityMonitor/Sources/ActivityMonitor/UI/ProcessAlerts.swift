import AppKit

/// The confirmations before Oriel quits or signals anything, as sheets on the window. Each names the processes and
/// says what will happen to them; Cancel is always there and Escape takes it.
enum ProcessAlerts {
    /// Quit, Force Quit or Cancel; with `force`, only Force Quit or Cancel. Nil when cancelled.
    static func confirmQuit(_ targets: [SignalTarget], force: Bool, in window: NSWindow) async -> ProcessAction? {
        let alert = NSAlert()
        alert.alertStyle = force ? .critical : .warning
        alert.messageText = (force ? "Force quit " : "Quit ") + subject(targets) + "?"
        alert.informativeText = force ? forceExplanation(targets) : quitExplanation(targets)
        if !force {
            alert.addButton(withTitle: "Quit")
        }
        let forceButton = alert.addButton(withTitle: "Force Quit")
        forceButton.hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        switch await alert.beginSheetModal(for: window) {
        case .alertFirstButtonReturn: return force ? .forceQuit : .quit
        case .alertSecondButtonReturn: return force ? nil : .forceQuit
        default: return nil
        }
    }

    static func confirmSignal(_ signal: ProcessSignal, _ targets: [SignalTarget], in window: NSWindow) async -> Bool {
        let alert = NSAlert()
        alert.alertStyle = [.kill, .stop].contains(signal) ? .critical : .warning
        alert.messageText = "Send \(signal.title) to \(subject(targets))?"
        alert.informativeText = "\(signal.name) \(signal.effect)"
        let send = alert.addButton(withTitle: "Send \(signal.name)")
        send.hasDestructiveAction = signal == .kill || signal == .stop
        alert.addButton(withTitle: "Cancel")
        return await alert.beginSheetModal(for: window) == .alertFirstButtonReturn
    }

    /// Before macOS's administrator prompt, for other users' processes.
    static func confirmAdministrator(_ action: ProcessAction, _ targets: [SignalTarget], in window: NSWindow) async -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .critical
        let owners = Set(targets.map(\.user)).sorted().joined(separator: ", ")
        alert.messageText = targets.count == 1
            ? "“\(targets[0].name)” belongs to \(owners)"
            : "\(targets.count) processes belong to other users (\(owners))"
        alert.informativeText = """
        Only an administrator can quit another user's process, so macOS will ask for an administrator's name and \
        password. A process that is part of macOS usually starts again by itself, and quitting it can disturb what \
        depends on it.
        """
        let verb = switch action {
        case .quit: "Quit"
        case .forceQuit: "Force Quit"
        case let .signal(signal): "Send \(signal.name)"
        }
        alert.addButton(withTitle: "\(verb) as Administrator…").hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        return await alert.beginSheetModal(for: window) == .alertFirstButtonReturn
    }

    static func explainRefusal(_ reasons: [(name: String, reason: String)], in window: NSWindow) async {
        guard let first = reasons.first else { return }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = reasons.count == 1
            ? "Oriel leaves “\(first.name)” running"
            : "Oriel leaves \(reasons.count) of these processes running"
        alert.informativeText = reasons.count == 1 ? first.reason : reasons.map { "\($0.name): \($0.reason)" }.joined(separator: "\n")
        alert.addButton(withTitle: "OK")
        _ = await alert.beginSheetModal(for: window)
    }

    static func showFailure(_ title: String, _ messages: [String], in window: NSWindow) async {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = messages.joined(separator: "\n")
        alert.addButton(withTitle: "OK")
        _ = await alert.beginSheetModal(for: window)
    }

    // MARK: Words

    /// "“Safari”", "“node” (PID 812)", or "3 processes".
    static func subject(_ targets: [SignalTarget]) -> String {
        guard targets.count == 1, let target = targets.first else { return "\(targets.count) processes" }
        return target.isApp ? "“\(target.name)”" : "“\(target.name)” (PID \(target.pid))"
    }

    static func quitExplanation(_ targets: [SignalTarget]) -> String {
        if targets.count == 1, let target = targets.first {
            return target.isApp
                ? "Quit lets \(target.name) save your work first. Force Quit ends it at once, and unsaved changes are lost."
                : "Quit asks the process to end (SIGTERM); it can tidy up first, or refuse. Force Quit ends it at once (SIGKILL)."
        }
        return names(targets) + ". Quit asks each one to end and lets apps save first; Force Quit ends them at once, and "
            + "unsaved changes are lost."
    }

    static func forceExplanation(_ targets: [SignalTarget]) -> String {
        let lead = targets.count == 1 ? "It ends at once" : names(targets) + " end at once"
        return lead + ", without saving anything. Unsaved changes are lost."
    }

    /// "Safari, node and 2 others".
    static func names(_ targets: [SignalTarget]) -> String {
        let names = targets.map(\.name)
        guard names.count > 1 else { return names.first ?? "" }
        if names.count <= 4 {
            return names.dropLast().joined(separator: ", ") + " and " + (names.last ?? "")
        }
        return names.prefix(3).joined(separator: ", ") + " and \(names.count - 3) others"
    }
}
