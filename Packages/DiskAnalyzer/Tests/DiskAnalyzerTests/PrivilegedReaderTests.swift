@testable import DiskAnalyzer
import Foundation
import ServiceManagement
import Synchronization
import Testing

/// Accepts connections and never answers them, like a helper that hangs.
private final class SilentListener: NSObject, NSXPCListenerDelegate, PrivilegedReading, Sendable {
    func listener(_: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: PrivilegedReading.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    func readFolders(_: [String], reply _: @escaping @Sendable (Data?, String?) -> Void) {}
}

/// Oriel's privileged helper as far as it runs in a test: the XPC conversation through an anonymous listener in this
/// process, the code-signature check, idling out, and the pure parts. Nothing is registered with macOS here: that would
/// add a background item to the Mac running the tests.
struct PrivilegedReaderTests {
    /// Counts the times the listener says its last connection closed.
    private final class IdleLog: Sendable {
        let count = Mutex(0)
    }

    private func listener(requirement: String?, idle: IdleLog = IdleLog()) -> (NSXPCListener, PrivilegedReaderListener) {
        let delegate = PrivilegedReaderListener(requirement: requirement) { idle.count.withLock { $0 += 1 } }
        let listener = NSXPCListener.anonymous()
        listener.delegate = delegate
        listener.resume()
        return (listener, delegate)
    }

    @Test func theHelperListsFoldersOverXPCAndIdlesOutWhenOrielHangsUp() async throws {
        let folder = try TemporaryFolder()
        try folder.file("A/big.bin", size: 2_000_000)
        try folder.file("A/B/small.txt", size: 10)
        let idle = IdleLog()
        let (listener, delegate) = listener(requirement: nil, idle: idle)
        defer { listener.invalidate() }
        let connection = NSXPCConnection(listenerEndpoint: listener.endpoint)
        let outcome = await PrivilegedReader.read(ElevatedRead.Request(folders: [folder.path]), over: connection)
        guard case let .read(result) = outcome else {
            Issue.record("expected listings, got \(outcome)")
            return
        }
        #expect(Set(result.listings.map(\.path)) == [folder.path, folder.path + "/A", folder.path + "/A/B"])
        let deadline = ContinuousClock.now + .seconds(5)
        while idle.count.withLock({ $0 }) == 0, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(idle.count.withLock { $0 } == 1)
        withExtendedLifetime(delegate) {}
    }

    /// A client whose signature does not meet the requirement is cut off before it is answered.
    @Test func anotherAppIsRefused() async throws {
        let folder = try TemporaryFolder()
        let requirement = CodeIdentity.requirement(identifier: "com.example.not-oriel", team: "ABCDE12345")
        let (listener, delegate) = listener(requirement: requirement)
        defer { listener.invalidate() }
        let connection = NSXPCConnection(listenerEndpoint: listener.endpoint)
        let outcome = await PrivilegedReader.read(ElevatedRead.Request(folders: [folder.path]), over: connection)
        #expect(outcome.failed)
        withExtendedLifetime(delegate) {}
    }

    @Test func aRequestItDoesNotUnderstandIsAnsweredWithWhy() async {
        let answer = await withCheckedContinuation { continuation in
            PrivilegedReaderService().readFolders(["--frobnicate"]) { data, reason in
                continuation.resume(returning: (data, reason))
            }
        }
        #expect(answer.0 == nil)
        #expect(answer.1?.isEmpty == false)
    }

    @Test func onlyOrielsSignatureMeetsTheRequirement() {
        #expect(CodeIdentity.requirement(identifier: "com.codertapsu.oriel", team: "4XVYLW8RXS")
            == #"identifier "com.codertapsu.oriel" and anchor apple generic and certificate leaf[subject.OU] = "4XVYLW8RXS""#)
        #expect(PrivilegedReader.label(for: "com.codertapsu.oriel") == "com.codertapsu.oriel.disk-reader")
        #expect(PrivilegedReader.label(for: "com.codertapsu.oriel.debug") == "com.codertapsu.oriel.debug.disk-reader")
    }

    @Test func macOSsStatesBecomeWhatTheWindowShows() {
        #expect(PrivilegedReader.status(of: .enabled) == .allowed)
        #expect(PrivilegedReader.status(of: .requiresApproval) == .needsApproval)
        #expect(PrivilegedReader.status(of: .notRegistered) == .notInstalled)
        #expect(PrivilegedReader.status(of: .notFound) == .notInstalled)
    }

    /// Only launchd's job for the helper, as root, starts it; the app, a root shell and the password route's root process,
    /// which `osascript` starts, do not.
    @Test func theHelperStartsOnlyAsLaunchdsJob() {
        let label = "com.codertapsu.oriel.disk-reader"
        let app = ["XPC_SERVICE_NAME": "application.com.codertapsu.oriel.1234.5678"]
        #expect(PrivilegedReaderDaemon.isHelper(environment: ["XPC_SERVICE_NAME": label], userID: 0, parentID: 1, label: label))
        #expect(PrivilegedReaderDaemon.isHelper(environment: [:], userID: 0, parentID: 1, label: label))
        #expect(!PrivilegedReaderDaemon.isHelper(environment: ["XPC_SERVICE_NAME": label], userID: 501, parentID: 1, label: label))
        #expect(!PrivilegedReaderDaemon.isHelper(environment: app, userID: 501, parentID: 1, label: label))
        #expect(!PrivilegedReaderDaemon.isHelper(environment: app, userID: 0, parentID: 4321, label: label))
        #expect(!PrivilegedReaderDaemon.isHelper(environment: [:], userID: 0, parentID: 4321, label: label))
    }

    /// A helper that never answers is given up on, and the request fails instead of waiting for ever.
    @Test func aHelperThatNeverAnswersIsGivenUpOn() async throws {
        let folder = try TemporaryFolder()
        let listener = NSXPCListener.anonymous()
        let silent = SilentListener()
        listener.delegate = silent
        listener.resume()
        defer { listener.invalidate() }
        let connection = NSXPCConnection(listenerEndpoint: listener.endpoint)
        let request = ElevatedRead.Request(folders: [folder.path])
        let outcome = await PrivilegedReader.read(request, over: connection, timeout: .milliseconds(200))
        #expect(outcome.failed)
    }
}
