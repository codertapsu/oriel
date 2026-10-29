import Foundation
import Synchronization
import Testing
@testable import Upload

struct SharedFolderTests {
    private func configuration(_ folder: URL, template: String = "") throws -> SharedFolderConfiguration {
        try SharedFolderConfiguration(path: folder.path, bookmark: SharedFolderAccess.bookmark(for: folder), publicURLTemplate: template)
    }

    @Test func anUploadIsCopiedInWholeWithItsFolders() async throws {
        let source = try TemporaryFolder()
        let target = try TemporaryFolder()
        defer {
            source.remove()
            target.remove()
        }
        let bytes = Data((0 ..< 3_000_000).map { UInt8($0 % 251) })
        let reports = Mutex<[UploadProgress]>([])
        let destination = try SharedFolderDestination(configuration: configuration(
            target.url,
            template: "https://files.example.com/{path}"
        ))
        let receipt = try await destination.upload(source.payload(bytes), to: ["8d3f", "Safari.png"]) { progress in
            reports.withLock { $0.append(progress) }
        }
        let copy = target.url.appending(path: "8d3f/Safari.png")
        #expect(FileManager.default.contents(atPath: copy.path) == bytes)
        #expect(receipt.link.absoluteString == "https://files.example.com/8d3f/Safari.png")
        #expect(reports.withLock { $0.last } == .sending(3_000_000, of: 3_000_000))
        // No partial file is left behind.
        #expect(try FileManager.default.contentsOfDirectory(atPath: copy.deletingLastPathComponent().path) == ["Safari.png"])
    }

    @Test func aNameInUseGetsANumberAndALocalFileLinksToItself() async throws {
        let source = try TemporaryFolder()
        let target = try TemporaryFolder()
        defer {
            source.remove()
            target.remove()
        }
        try target.file("Safari.png", contents: Data("old".utf8))
        let receipt = try await SharedFolderDestination(configuration: configuration(target.url)).upload(
            source.payload(Data("new".utf8)),
            to: ["Safari.png"]
        ) { _ in }
        #expect(receipt.path == ["Safari 2.png"])
        #expect(receipt.link.isFileURL)
        #expect(receipt.link.lastPathComponent == "Safari 2.png")
        #expect(FileManager.default.contents(atPath: target.url.appending(path: "Safari.png").path) == Data("old".utf8))
    }

    @Test func aMissingReadOnlyOrWrongFolderIsExplained() async throws {
        let source = try TemporaryFolder()
        let target = try TemporaryFolder()
        defer {
            source.remove()
            target.remove()
        }
        let payload = try source.payload(Data("x".utf8))
        let gone = SharedFolderDestination(configuration: SharedFolderConfiguration(path: target.url.appending(path: "nope").path))
        await #expect(throws: UploadError.self) { try await gone.upload(payload, to: ["a.png"]) { _ in } }

        let file = try target.file("plain.txt", contents: Data())
        let notFolder = SharedFolderDestination(configuration: SharedFolderConfiguration(path: file.path))
        await #expect(throws: UploadError
            .invalidSettings("“\((file.path as NSString).abbreviatingWithTildeInPath)” is a file, not a folder."))
        {
            try await notFolder.upload(payload, to: ["a.png"]) { _ in }
        }

        let locked = target.url.appending(path: "locked", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: locked.path)
        let readOnly = SharedFolderDestination(configuration: SharedFolderConfiguration(path: locked.path))
        await #expect(throws: UploadError.forbidden("Oriel can't write into “\((locked.path as NSString).abbreviatingWithTildeInPath)”.")) {
            try await readOnly.testConnection()
        }
    }

    @Test func connectionWritesAndRemovesAProbe() async throws {
        let target = try TemporaryFolder()
        defer { target.remove() }
        let message = try await SharedFolderDestination(configuration: configuration(target.url)).testConnection()
        #expect(message.hasPrefix("Oriel can write into"))
        #expect(try FileManager.default.contentsOfDirectory(atPath: target.url.path).isEmpty)
    }

    @Test func theBookmarkFollowsARename() async throws {
        let parent = try TemporaryFolder()
        let source = try TemporaryFolder()
        defer {
            parent.remove()
            source.remove()
        }
        let before = parent.url.appending(path: "Shots", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: before, withIntermediateDirectories: true)
        let original = try configuration(before)
        let after = parent.url.appending(path: "Team Shots", directoryHint: .isDirectory)
        try FileManager.default.moveItem(at: before, to: after)

        let receipt = try await SharedFolderDestination(configuration: original)
            .upload(source.payload(Data("x".utf8)), to: ["a.png"]) { _ in }
        #expect(FileManager.default.fileExists(atPath: after.appending(path: "a.png").path))
        guard case let .sharedFolder(updated) = receipt.updatedTarget else {
            Issue.record("the moved folder's new place was not kept")
            return
        }
        #expect(URL(fileURLWithPath: updated.path).resolvingSymlinksInPath().path == after.resolvingSymlinksInPath().path)
        // What the upload learned replaces only the folder's place.
        let learned = UploadTarget.sharedFolder(original).learning(.sharedFolder(updated), startedWith: .sharedFolder(original))
        #expect(learned == .sharedFolder(updated))
    }

    @Test func aFolderChosenAgainDuringTheUploadIsKept() {
        let original = SharedFolderConfiguration(path: "/a", bookmark: Data([1]))
        let chosenMeanwhile = SharedFolderConfiguration(path: "/b", bookmark: Data([2]))
        let learned = SharedFolderConfiguration(path: "/a2", bookmark: Data([3]))
        #expect(UploadTarget.sharedFolder(chosenMeanwhile)
            .learning(.sharedFolder(learned), startedWith: .sharedFolder(original)) == .sharedFolder(chosenMeanwhile))
        var drive = GoogleDriveConfiguration(clientID: "c")
        drive.sharesPublicly = false
        var found = GoogleDriveConfiguration(clientID: "c")
        found.createdFolderID = "F"
        guard case let .googleDrive(merged) = UploadTarget.googleDrive(drive)
            .learning(.googleDrive(found), startedWith: .googleDrive(drive))
        else {
            Issue.record("not a drive")
            return
        }
        #expect(merged.createdFolderID == "F")
        #expect(merged.sharesPublicly == false)
    }
}
