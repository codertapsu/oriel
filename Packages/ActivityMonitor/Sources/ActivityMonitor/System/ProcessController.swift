import AppKit
import Darwin
import OrielCore

/// Carries out a confirmed action on a process. Before anything is sent it checks that the pid still belongs to the
/// process the user confirmed (same start time), so a pid that was given up and reused while a dialog was open is
/// left alone.
enum ProcessController {
    enum Outcome: Equatable, Sendable {
        case done
        case failed(String)
        /// The user cancelled the administrator prompt.
        case cancelled
    }

    private static let log = Log.logger("activity")

    /// Quits or signals one of the user's own processes, as `SignalPolicy` decided.
    static func perform(_ decision: SignalDecision, on target: SignalTarget) -> Outcome {
        if let problem = check(target) {
            return .failed(problem)
        }
        switch decision {
        case let .refuse(reason):
            return .failed(reason)
        case let .terminateApp(force):
            guard let app = NSRunningApplication(processIdentifier: target.pid) else { return .failed(ended(target)) }
            let asked = force ? app.forceTerminate() : app.terminate()
            return asked ? .done : .failed("“\(target.name)” did not accept the request to quit. Try Force Quit.")
        case let .send(signal):
            return send(signal, to: target)
        case .needsAdministrator:
            return .failed("“\(target.name)” belongs to \(target.user); only an administrator can quit it.")
        }
    }

    /// Signals other users' processes through macOS's administrator prompt, once for all of them. Processes that ended
    /// or whose pid was reused since the user confirmed are left out.
    static func performAsAdministrator(_ signal: ProcessSignal, on targets: [SignalTarget]) async -> Outcome {
        let current = targets.filter { check($0) == nil }
        guard let arguments = AdministratorKill.arguments(signal: signal, pids: current.map(\.pid)) else {
            return .failed(targets.count == 1 ? targets.first.map(ended) ?? "" : "Those processes have already quit.")
        }
        do {
            // The prompt waits for the user, so the timeout is long.
            let result = try await CommandRunner.run(AdministratorKill.osascript, arguments, timeout: .seconds(300))
            if result.status == 0 {
                log.notice("sent \(signal.name, privacy: .public) to \(current.count) processes as an administrator")
                return .done
            }
            if AdministratorKill.isCancellation(result.errorText) {
                return .cancelled
            }
            let names = current.map { "“\($0.name)”" }.joined(separator: ", ")
            if result.errorText.contains("No such process") {
                return .failed("\(names) had already quit.")
            }
            return .failed("\(names) could not be signalled: \(result.errorText)")
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Why `target` is no longer the process the user confirmed, if it is not.
    static func check(_ target: SignalTarget) -> String? {
        guard target.pid > 1 else { return "That process cannot be signalled." }
        guard let current = ProcessTable.basics(of: target.pid), current.startTime == target.identity.startTime else {
            return ended(target)
        }
        return nil
    }

    private static func send(_ signal: ProcessSignal, to target: SignalTarget) -> Outcome {
        // Never 0 or a negative pid: kill(2) would signal a whole process group, or every process the user owns.
        guard target.pid > 1 else { return .failed("That process cannot be signalled.") }
        guard kill(target.pid, signal.number) == 0 else {
            switch errno {
            case ESRCH: return .failed(ended(target))
            case EPERM: return .failed("macOS does not let Oriel signal “\(target.name)”.")
            default: return .failed(String(cString: strerror(errno)))
            }
        }
        log.notice("sent \(signal.name, privacy: .public) to \(target.pid)")
        return .done
    }

    private static func ended(_ target: SignalTarget) -> String {
        "“\(target.name)” has already quit."
    }
}
