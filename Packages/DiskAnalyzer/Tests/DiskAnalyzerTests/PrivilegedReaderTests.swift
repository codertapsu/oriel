@testable import DiskAnalyzer
import Foundation
import Security
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

    /// Records the user ID the listener was asked to admit.
    private final class AdmissionLog: Sendable {
        let userIDs = Mutex<[uid_t]>([])
    }

    /// Whether a read saw that it was to stop.
    private final class StopLog: Sendable {
        let stopped = Mutex(false)
    }

    private func listener(
        requirement: String?,
        admits: @escaping @Sendable (uid_t) -> Bool = { _ in true },
        read: @escaping @Sendable (ElevatedRead.Request, CancellationFlag) -> ElevatedRead.Result = ElevatedRead.read(_:cancellation:),
        idle: IdleLog = IdleLog()
    ) -> (NSXPCListener, PrivilegedReaderListener) {
        let delegate = PrivilegedReaderListener(requirement: requirement, admits: admits, read: read) { idle.count.withLock { $0 += 1 } }
        let listener = NSXPCListener.anonymous()
        listener.delegate = delegate
        listener.resume()
        return (listener, delegate)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func theHelperListsFoldersOverXPCAndIdlesOutWhenOrielHangsUp() async throws {
        let folder = try TemporaryFolder()
        try folder.file("A/big.bin", size: 2_000_000)
        try folder.file("A/B/small.txt", size: 10)
        let idle = IdleLog()
        let (listener, delegate) = listener(requirement: nil, idle: idle)
        defer { listener.invalidate() }
        let connection = NSXPCConnection(listenerEndpoint: listener.endpoint)
        let outcome = await PrivilegedReader.read(ElevatedRead.Request(folders: [folder.path]), over: connection).outcome
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
        let requirement = CodeIdentity.requirement(identifier: "com.example.not-oriel", team: "ABCDE12345", developerID: false)
        let (listener, delegate) = listener(requirement: requirement)
        defer { listener.invalidate() }
        let connection = NSXPCConnection(listenerEndpoint: listener.endpoint)
        let answer = await PrivilegedReader.read(ElevatedRead.Request(folders: [folder.path]), over: connection)
        #expect(answer.outcome.failed)
        #expect(answer.connectionFailed)
        withExtendedLifetime(delegate) {}
    }

    /// The daemon is the whole Mac's, so Oriel run by another user, who is not an administrator, reaches it too: it is
    /// turned away by the user ID its process runs as, before it is answered.
    @Test func anotherUsersOrielIsRefused() async throws {
        let folder = try TemporaryFolder()
        let asked = AdmissionLog()
        let (listener, delegate) = listener(requirement: nil, admits: { userID in
            asked.userIDs.withLock { $0.append(userID) }
            return false
        })
        defer { listener.invalidate() }
        let connection = NSXPCConnection(listenerEndpoint: listener.endpoint)
        let answer = await PrivilegedReader.read(ElevatedRead.Request(folders: [folder.path]), over: connection)
        #expect(answer.outcome.failed)
        #expect(asked.userIDs.withLock { $0 } == [geteuid()])
        withExtendedLifetime(delegate) {}
    }

    @Test func onlyAdministratorsAreAdmitted() {
        #expect(Administrators.contains(0))
        #expect(!Administrators.contains(uid_t(bitPattern: -2))) // nobody
        #expect(!Administrators.contains(1)) // daemon
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

    /// A Debug build, signed for development and always debuggable, asks for Oriel's identifier and team; a release also
    /// for Developer ID and no `get-task-allow`, which a Release build made on this Mac has, so it cannot speak for
    /// the installed app (checked with `codesign -v -R` on both).
    @Test func onlyOrielsSignatureMeetsTheRequirement() {
        let debug = CodeIdentity.requirement(identifier: "com.codertapsu.oriel.debug", team: "4XVYLW8RXS", developerID: false)
        #expect(debug == #"identifier "com.codertapsu.oriel.debug" and anchor apple generic"#
            + #" and certificate leaf[subject.OU] = "4XVYLW8RXS""#)
        let release = CodeIdentity.requirement(identifier: "com.codertapsu.oriel", team: "4XVYLW8RXS", developerID: true)
        #expect(release == #"identifier "com.codertapsu.oriel" and anchor apple generic and certificate leaf[subject.OU] = "4XVYLW8RXS""#
            + #" and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"#
            + #" and !entitlement["com.apple.security.get-task-allow"] exists"#)
        for text in [debug, release] {
            var requirement: SecRequirement?
            #expect(SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess)
        }
        #expect(PrivilegedReader.label(for: "com.codertapsu.oriel") == "com.codertapsu.oriel.disk-reader")
        #expect(PrivilegedReader.label(for: "com.codertapsu.oriel.debug") == "com.codertapsu.oriel.debug.disk-reader")
    }

    /// macOS's own code is signed by Apple, not with Developer ID.
    @Test func appleSignedCodeIsNotDeveloperID() throws {
        var code: SecStaticCode?
        #expect(SecStaticCodeCreateWithPath(URL(fileURLWithPath: "/usr/bin/true") as CFURL, [], &code) == errSecSuccess)
        var information: CFDictionary?
        _ = try SecCodeCopySigningInformation(#require(code), SecCSFlags(rawValue: kSecCSSigningInformation), &information)
        let values = try #require(information as? [String: Any])
        let leaf = try #require((values[kSecCodeInfoCertificates as String] as? [SecCertificate])?.first)
        #expect(!CodeIdentity.isDeveloperIDApplication(leaf))
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

    /// A helper that never answers is given up on, and the request fails instead of waiting for ever. It is not sent
    /// again: the helper may still be reading.
    @Test func aHelperThatNeverAnswersIsGivenUpOn() async throws {
        let folder = try TemporaryFolder()
        let listener = NSXPCListener.anonymous()
        let silent = SilentListener()
        listener.delegate = silent
        listener.resume()
        defer { listener.invalidate() }
        let connection = NSXPCConnection(listenerEndpoint: listener.endpoint)
        let request = ElevatedRead.Request(folders: [folder.path])
        let answer = await PrivilegedReader.read(request, over: connection, timeout: .milliseconds(200))
        #expect(answer.outcome.failed)
        #expect(!answer.connectionFailed)
    }

    /// A helper left from an older Oriel lists in an older format, which this Oriel cannot count by: its answer is refused
    /// rather than misread, as the password route refuses one.
    @Test func anAnswerInAnOlderFormatIsRefused() async {
        let (listener, delegate) = listener(requirement: nil, read: { _, _ in
            ElevatedRead.Result(version: ElevatedRead.version - 1, listings: [])
        })
        defer { listener.invalidate() }
        let connection = NSXPCConnection(listenerEndpoint: listener.endpoint)
        let answer = await PrivilegedReader.read(ElevatedRead.Request(folders: ["/x"]), over: connection)
        #expect(answer.outcome.failed)
        #expect(!answer.connectionFailed)
        withExtendedLifetime(delegate) {}
    }

    /// When Oriel stops waiting, the helper stops reading rather than go on as root with nobody to answer, and, its last
    /// connection closed, idles out at once: a read on the connection's own queue would hold back both until its end.
    @Test func theHelperStopsReadingWhenOrielStopsWaiting() async throws {
        let idle = IdleLog()
        let log = StopLog()
        let (listener, delegate) = listener(requirement: nil, read: { _, cancellation in
            // A read of millions of files, as far as this test waits.
            while !cancellation.isCancelled {
                usleep(1000)
            }
            log.stopped.withLock { $0 = true }
            return ElevatedRead.Result(listings: [])
        }, idle: idle)
        defer { listener.invalidate() }
        let connection = NSXPCConnection(listenerEndpoint: listener.endpoint)
        let answer = await PrivilegedReader.read(ElevatedRead.Request(folders: ["/x"]), over: connection, timeout: .milliseconds(200))
        #expect(answer.outcome.failed)
        #expect(!answer.connectionFailed)
        try await waitUntil { log.stopped.withLock { $0 } && idle.count.withLock { $0 } == 1 }
        #expect(log.stopped.withLock { $0 })
        #expect(idle.count.withLock { $0 } == 1)
        withExtendedLifetime(delegate) {}
    }
}
