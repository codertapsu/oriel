import CoreGraphics
import Foundation
import Hotkeys
import OrielTestSupport
import Testing

/// A trackpad sequence recorded on a real Mac by `GestureRecorderTests`, and what the recognizer should make of it, in
/// `Tests/Fixtures/gestures/<name>.json`.
struct GestureFixture: Codable, Sendable, CustomTestStringConvertible {
    enum Outcome: String, Codable, Sendable {
        case forward
        case backward
        /// The switcher must not open.
        case none
    }

    struct Touch: Codable, Sendable {
        var id: Int
        var x: Double
        var y: Double
        var resting: Bool
    }

    var name: String
    var expected: Outcome
    /// Where and on what it was recorded.
    var recorded: String
    var frames: [[Touch]]

    var testDescription: String {
        name
    }

    var samples: [[TouchSample]] {
        frames.map { frame in
            frame.map { TouchSample(identity: $0.id, position: CGPoint(x: $0.x, y: $0.y), isResting: $0.resting) }
        }
    }

    init(name: String, expected: Outcome, recorded: String, samples: [[TouchSample]]) {
        self.name = name
        self.expected = expected
        self.recorded = recorded
        frames = samples.map { frame in
            frame.map { Touch(id: $0.identity, x: Double($0.position.x), y: Double($0.position.y), resting: $0.isResting) }
        }
    }

    static func folder(filePath: String = #filePath) -> URL {
        Fixtures.folder("gestures", filePath: filePath)
    }

    /// Every recorded fixture, by name.
    static func all() -> [GestureFixture] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder(), includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(GestureFixture.self, from: Data(contentsOf: $0)) }
            .sorted { $0.name < $1.name }
    }

    func write() throws {
        try FileManager.default.createDirectory(at: Self.folder(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: Self.folder().appending(path: name + ".json"))
    }
}
