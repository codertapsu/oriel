import Darwin
import Foundation
import os

/// Runs one of the system's command-line tools (`ps`, `nettop`, `sample`, `osascript`) and collects what it prints.
///
/// It uses `posix_spawn` and a blocking wait rather than `Process`, whose `waitUntilExit()` polls a run loop and adds
/// tens of milliseconds to every run. The child inherits only its three standard descriptors and gets a C locale (so
/// `ps` writes its decimal point as a point); it is terminated when it outlives its timeout or the task that started it
/// is cancelled, so a window that closes leaves nothing running.
nonisolated enum CommandRunner {
    struct Result: Sendable {
        let status: Int32
        let output: Data
        let errorOutput: Data

        var text: String {
            ByteText.string(output)
        }

        var errorText: String {
            ByteText.string(errorOutput).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    struct LaunchError: LocalizedError, Sendable {
        let code: Int32

        var errorDescription: String? {
            String(cString: strerror(code))
        }
    }

    static func run(_ executable: URL, _ arguments: [String], timeout: Duration = .seconds(10)) async throws -> Result {
        let child = Child()
        let path = executable.path(percentEncoded: false)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    continuation.resume(with: Swift.Result { try child.run(path, arguments, timeout: timeout) })
                }
            }
        } onCancel: {
            child.terminate()
        }
    }

    /// One child process. The lock orders launching, terminating and reaping, so a signal never reaches a pid the child
    /// gave up: the child is waited for without being reaped, marked finished, and only then reaped.
    private final class Child: @unchecked Sendable {
        private struct State {
            var pid: pid_t = 0
            var finished = false
            var stopped = false
        }

        private let state = OSAllocatedUnfairLock(initialState: State())

        /// Blocks its dispatch thread until the child exits.
        func run(_ path: String, _ arguments: [String], timeout: Duration) throws -> Result {
            var output: [Int32] = [-1, -1]
            var errors: [Int32] = [-1, -1]
            guard pipe(&output) == 0 else { throw LaunchError(code: errno) }
            guard pipe(&errors) == 0 else {
                let code = errno
                close(output[0])
                close(output[1])
                throw LaunchError(code: code)
            }
            // A child some other code starts must not inherit the write ends, or the reads below would wait for it.
            for descriptor in output + errors {
                _ = fcntl(descriptor, F_SETFD, FD_CLOEXEC)
            }
            let outputEnd = output[1]
            let errorEnd = errors[1]
            let launched = state.withLock { state -> Int32 in
                guard !state.stopped else { return ECANCELED }
                return Self.spawn(path, arguments, output: outputEnd, errors: errorEnd, pid: &state.pid)
            }
            close(output[1])
            close(errors[1])
            guard launched == 0 else {
                close(output[0])
                close(errors[0])
                throw launched == ECANCELED ? CancellationError() : LaunchError(code: launched)
            }
            let watchdog = DispatchWorkItem { [weak self] in self?.terminate() }
            let seconds = Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + seconds, execute: watchdog)
            // stderr is read beside stdout, so a child that fills one pipe never waits on the other.
            let group = DispatchGroup()
            let errorData = OSAllocatedUnfairLock(initialState: Data())
            let errorDescriptor = errors[0]
            DispatchQueue.global(qos: .utility).async(group: group) {
                let data = Self.readAll(errorDescriptor)
                errorData.withLock { $0 = data }
            }
            let data = Self.readAll(output[0])
            group.wait()
            close(output[0])
            close(errors[0])
            let status = wait()
            watchdog.cancel()
            if state.withLock({ $0.stopped }) {
                throw CancellationError()
            }
            return Result(status: status, output: data, errorOutput: errorData.withLock { $0 })
        }

        func terminate() {
            state.withLock { state in
                state.stopped = true
                if state.pid > 0, !state.finished {
                    kill(state.pid, SIGTERM)
                }
            }
        }

        /// Waits for the child to exit, marks it finished, then reaps it; the exit status, or 128 + the signal.
        private func wait() -> Int32 {
            let pid = state.withLock { $0.pid }
            var info = siginfo_t()
            while waitid(P_PID, id_t(pid), &info, WEXITED | WNOWAIT) != 0, errno == EINTR {}
            state.withLock { $0.finished = true }
            var status: Int32 = 0
            while waitpid(pid, &status, 0) < 0, errno == EINTR {}
            let signal = status & 0x7F
            return signal == 0 ? (status >> 8) & 0xFF : 128 + signal
        }

        private static func spawn(_ path: String, _ arguments: [String], output: Int32, errors: Int32, pid: inout pid_t) -> Int32 {
            var actions: posix_spawn_file_actions_t?
            posix_spawn_file_actions_init(&actions)
            defer { posix_spawn_file_actions_destroy(&actions) }
            posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
            posix_spawn_file_actions_adddup2(&actions, output, 1)
            posix_spawn_file_actions_adddup2(&actions, errors, 2)
            var attributes: posix_spawnattr_t?
            posix_spawnattr_init(&attributes)
            defer { posix_spawnattr_destroy(&attributes) }
            // Nothing but stdin, stdout and stderr reaches the child: not Oriel's sockets or files. Dispatch threads block
            // signals, and a child would inherit that, so it starts with no signal blocked or ignored: a timeout's
            // SIGTERM must reach it.
            var noSignals: sigset_t = 0
            var allSignals: sigset_t = ~0
            posix_spawnattr_setsigmask(&attributes, &noSignals)
            posix_spawnattr_setsigdefault(&attributes, &allSignals)
            posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF))
            let words: [String] = [path] + arguments
            let variables: [String] = ["LC_ALL=C", "LANG=C", "PATH=/usr/bin:/bin:/usr/sbin:/sbin"]
            let argv = words.map { strdup($0) } + [nil]
            let environment = variables.map { strdup($0) } + [nil]
            defer {
                (argv + environment).forEach { free($0) }
            }
            return posix_spawn(&pid, path, &actions, &attributes, argv, environment)
        }

        private static func readAll(_ descriptor: Int32) -> Data {
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 65536)
            while true {
                let count = buffer.withUnsafeMutableBytes { read(descriptor, $0.baseAddress, $0.count) }
                if count > 0 {
                    data.append(buffer, count: count)
                } else if count < 0, errno == EINTR {
                    continue
                } else {
                    return data
                }
            }
        }
    }
}
