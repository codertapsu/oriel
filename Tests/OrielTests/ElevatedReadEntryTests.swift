import Foundation
import Testing

/// Read as Administrator runs Oriel's own executable again as root, only to list folders. Here it runs as the user, on a
/// folder of the test's: the listing mode starts before anything else, prints its JSON and exits.
struct ElevatedReadEntryTests {
    @Test func theExecutableListsFoldersAndExits() throws {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "OrielListing-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder.appending(path: "Inner"), withIntermediateDirectories: true)
        try Data(count: 2_000_000).write(to: folder.appending(path: "Inner/big.bin"))
        defer { try? FileManager.default.removeItem(at: folder) }

        let process = Process()
        process.executableURL = Bundle.main.executableURL
        process.arguments = ["--disk-read-folders", "--threshold", "1000000", "--", folder.path]
        let stdout = Pipe()
        process.standardOutput = stdout
        try process.run()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["version"] as? Int == 2)
        let listings = try #require(json["listings"] as? [[String: Any]])
        #expect(Set(listings.compactMap { $0["path"] as? String }) == [folder.path, folder.path + "/Inner"])
    }
}
