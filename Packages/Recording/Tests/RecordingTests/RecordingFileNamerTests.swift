import Foundation
@testable import Recording
import Testing

struct RecordingFileNamerTests {
    private let utc = TimeZone(identifier: "UTC") ?? .current

    @Test func namesRecordingsLikeMacOSDoes() {
        // 2026-10-29 14:05:09 UTC.
        let date = Date(timeIntervalSince1970: 1_793_282_709)
        #expect(RecordingFileNamer.baseName(for: date, timeZone: utc) == "Oriel Recording 2026-10-29 at 14.05.09")
    }

    @Test func numbersNamesThatAreTaken() {
        let folder = URL(filePath: "/tmp/out", directoryHint: .isDirectory)
        let taken: Set = ["A.mp4", "A 2.mp4"]
        let url = RecordingFileNamer.uniqueURL(in: folder, baseName: "A", pathExtension: "mp4") { taken.contains($0.lastPathComponent) }
        #expect(url.lastPathComponent == "A 3.mp4")
        #expect(url.deletingLastPathComponent().path == "/tmp/out")
    }

    @Test func namesExportsAfterTheirMovie() {
        let movie = URL(filePath: "/tmp/out/Oriel Recording 2026-10-29 at 14.05.09.mp4")
        let gif = RecordingFileNamer.sibling(of: movie, pathExtension: "gif") { _ in false }
        #expect(gif.lastPathComponent == "Oriel Recording 2026-10-29 at 14.05.09.gif")
        let cfr = RecordingFileNamer.sibling(of: movie, suffix: " (CFR)", pathExtension: "mp4") { _ in false }
        #expect(cfr.lastPathComponent == "Oriel Recording 2026-10-29 at 14.05.09 (CFR).mp4")
        #expect(cfr.deletingLastPathComponent() == movie.deletingLastPathComponent())
    }

    @Test func formatsTheElapsedTime() {
        #expect(ElapsedTime.string(.zero) == "0:00")
        #expect(ElapsedTime.string(.milliseconds(7900)) == "0:07")
        #expect(ElapsedTime.string(.seconds(754)) == "12:34")
        #expect(ElapsedTime.string(.seconds(3723)) == "1:02:03")
        #expect(ElapsedTime.string(.seconds(-5)) == "0:00")
        #expect(ElapsedTime.spoken(.seconds(61)) == "1 minute 1 second")
        #expect(ElapsedTime.spoken(.seconds(3600)) == "1 hour")
        #expect(ElapsedTime.spoken(.zero) == "0 seconds")
    }
}
