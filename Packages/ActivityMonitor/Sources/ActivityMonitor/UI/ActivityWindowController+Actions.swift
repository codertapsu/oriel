import AppKit
import SharedUI

/// Quit, Force Quit, Send Signal, Sample Process, Reveal in Finder and Copy. Nothing is sent without a confirmation
/// that names the processes; protected processes are refused with the reason, and other users' processes go through
/// macOS's administrator prompt.
extension ActivityWindowController {
    /// The processes an action applies to: the row a menu was opened on or the selection, a group row standing for its
    /// app.
    var actionTargets: [ProcessMetrics] {
        list.clickedOrSelected
    }

    func quitSelection(force: Bool) {
        perform(force ? .forceQuit : .quit, on: actionTargets)
    }

    func send(_ signal: ProcessSignal) {
        perform(.signal(signal), on: actionTargets)
    }

    /// Confirms, then carries out `action`, one dialog for the whole selection.
    func perform(_ action: ProcessAction, on processes: [ProcessMetrics]) {
        guard let window, !processes.isEmpty else { return }
        let targets = processes.map(SignalTarget.init)
        let refused = targets.compactMap { target in policy.refusal(for: target).map { (name: target.name, reason: $0) } }
        let allowed = targets.filter { policy.refusal(for: $0) == nil }
        Task {
            if !refused.isEmpty {
                await ProcessAlerts.explainRefusal(refused, in: window)
            }
            guard !allowed.isEmpty else { return }
            let chosen: ProcessAction? = switch action {
            case .quit, .forceQuit:
                await ProcessAlerts.confirmQuit(allowed, force: action == .forceQuit, in: window)
            case let .signal(signal):
                await ProcessAlerts.confirmSignal(signal, allowed, in: window) ? action : nil
            }
            guard let chosen else { return }
            await carryOut(chosen, on: allowed, in: window)
        }
    }

    private func carryOut(_ action: ProcessAction, on targets: [SignalTarget], in window: NSWindow) async {
        var failures: [String] = []
        var administrator: [SignalTarget] = []
        for target in targets {
            let decision = policy.decide(action, for: target)
            if case .needsAdministrator = decision {
                administrator.append(target)
            } else if case let .failed(message) = ProcessController.perform(decision, on: target) {
                failures.append(message)
            }
        }
        if !administrator.isEmpty, await ProcessAlerts.confirmAdministrator(action, administrator, in: window) {
            let outcome = await ProcessController.performAsAdministrator(action.signal, on: administrator)
            if case let .failed(message) = outcome {
                failures.append(message)
            }
        }
        if !failures.isEmpty {
            let title = switch action {
            case .quit, .forceQuit: failures.count == 1 ? "A process was not quit" : "Some processes were not quit"
            case .signal: failures.count == 1 ? "The signal was not sent" : "Some signals were not sent"
            }
            await ProcessAlerts.showFailure(title, failures, in: window)
        }
        session?.wake()
    }

    /// Sample Process…: three seconds of the process's call stacks, then the report opens.
    func sampleSelection() {
        guard let window, let process = actionTargets.first, Self.canSample(process) else { return }
        let target = SignalTarget(process)
        if let problem = ProcessController.check(target) {
            Task { await ProcessAlerts.showFailure("Oriel could not sample “\(process.name)”", [problem], in: window) }
            return
        }
        Toast.show("Sampling “\(process.name)” for \(SampleReport.seconds) seconds…", symbol: "waveform.path.ecg", duration: .seconds(3))
        Task {
            do {
                let report = try await SampleReport.record(pid: process.pid, name: process.name)
                NSWorkspace.shared.open(report)
            } catch {
                await ProcessAlerts.showFailure("Oriel could not sample “\(process.name)”", [error.localizedDescription], in: window)
            }
        }
    }

    /// The user's own live processes: `sample` needs the same rights as a debugger.
    static func canSample(_ process: ProcessMetrics) -> Bool {
        process.isMine && process.status != .zombie && process.pid > 0
    }

    /// Shows the app bundle, or the executable, in Finder.
    func reveal(_ process: ProcessMetrics) {
        guard let path = process.app?.bundlePath ?? process.path else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    /// ⌘C: one line per process, its name, pid and path separated by tabs, ready for a spreadsheet.
    func copySelection() {
        let lines = list.selectedProcesses.map { [$0.name, String($0.pid), $0.path ?? ""].joined(separator: "\t") }
        guard !lines.isEmpty else { return }
        Pasteboard.copy(lines.joined(separator: "\n"))
    }

    func copy(_ text: String) {
        Pasteboard.copy(text)
    }

    /// The details of one process as text, for a bug report.
    static func summaryText(_ process: ProcessMetrics) -> String {
        [
            "\(process.name) (\(process.pid))",
            "User: \(process.user)",
            "Path: \(process.path ?? ActivityFormat.dash)",
            "Kind: \(process.kind.title)",
            "CPU: \(ActivityFormat.percentWithSign(process.cpuPercent)), CPU time \(ActivityFormat.cpuTime(process.cpuTime))",
            "Memory: \(ActivityFormat.memory(process.memoryForRanking)), real memory \(ActivityFormat.memory(process.realMemory))",
        ].joined(separator: "\n")
    }
}
