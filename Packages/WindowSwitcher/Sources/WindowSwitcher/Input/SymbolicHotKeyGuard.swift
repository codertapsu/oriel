import Darwin
import Dispatch
import Synchronization

/// Turns the system hot keys we disabled back on when the process ends (PLAN §7.1.4): at `exit` through
/// `atexit`, and on SIGTERM, SIGINT and SIGHUP through dispatch signal sources. A dispatch source runs its
/// handler on a queue, not in signal context, so restoring there is safe; the handler then re-raises the
/// signal with its default action, so the process still ends as it would have.
///
/// `kill -9` and crashes skip all of this; the module restores what the settings recorded when it activates.
final nonisolated class SymbolicHotKeyGuard: Sendable {
    /// The process-wide guard; the first `track` with ids installs the exit handlers.
    static let shared = SymbolicHotKeyGuard(installsExitHandlers: true)

    private struct State {
        var disabled: [Int32] = []
        var control: (any SymbolicHotKeyControlling)?
        var handlersInstalled = false
        var signalSources: [any DispatchSourceSignal] = []
    }

    private let installsExitHandlers: Bool
    private let state = Mutex(State())

    init(installsExitHandlers: Bool) {
        self.installsExitHandlers = installsExitHandlers
    }

    /// The ids currently disabled by us.
    var disabled: [Int32] {
        state.withLock { $0.disabled }
    }

    /// Records what is disabled now, and through what to turn it back on.
    func track(_ ids: [Int32], control: any SymbolicHotKeyControlling) {
        let install = state.withLock { state in
            state.disabled = ids
            state.control = control
            let install = installsExitHandlers && !ids.isEmpty && !state.handlersInstalled
            if install {
                state.handlersInstalled = true
            }
            return install
        }
        if install {
            installHandlers()
        }
    }

    /// Re-enables every hot key we disabled. Safe to call more than once.
    @discardableResult
    func restore() -> [Int32] {
        let (ids, control) = state.withLock { state in
            defer { state.disabled = [] }
            return (state.disabled, state.control)
        }
        for id in ids {
            control?.setSymbolicHotKey(id, enabled: true)
        }
        return ids
    }

    private func installHandlers() {
        atexit {
            SymbolicHotKeyGuard.shared.restore()
        }
        var sources: [any DispatchSourceSignal] = []
        for signalNumber in [SIGTERM, SIGINT, SIGHUP] {
            // The default action would end the process before the source's handler runs.
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .global(qos: .userInitiated))
            source.setEventHandler {
                SymbolicHotKeyGuard.shared.restore()
                signal(signalNumber, SIG_DFL)
                kill(getpid(), signalNumber)
            }
            source.resume()
            sources.append(source)
        }
        state.withLock { $0.signalSources = sources }
    }
}
