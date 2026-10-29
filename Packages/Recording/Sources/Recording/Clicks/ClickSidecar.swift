import Foundation

/// The clicks of one recording, kept next to the movie as `<name>.oriel-clicks.json` so the video editor's Auto
/// Zoom can find them later (PLAN §17).
///
/// The file is versioned: `format` names it and `version` is bumped whenever a reader would misread a newer file.
/// A reader takes every version up to `currentVersion` and refuses newer ones, rather than guessing.
///
/// ```json
/// {"clicks":[{"button":"left","time":1.25,"x":0.4812,"y":0.2207}],"duration":42.5,"format":"oriel-clicks",
///  "height":1080,"version":1,"width":1920}
/// ```
nonisolated struct ClickSidecar: Codable, Equatable, Sendable {
    /// Why a sidecar could not be read.
    enum ReadError: LocalizedError, Equatable {
        /// The file is JSON, but not a click file.
        case notAClickFile
        /// The file was written by a newer Oriel.
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .notAClickFile: "The click file is not one Oriel wrote."
            case let .unsupportedVersion(version): "The click file is from a newer version of Oriel (format \(version))."
            }
        }
    }

    /// The name in every click file's `format` field.
    static let formatName = "oriel-clicks"
    /// The version this build writes and the newest it reads.
    static let currentVersion = 1
    /// What follows the movie's name in the sidecar's file name.
    static let fileSuffix = ".oriel-clicks.json"
    /// The most clicks a file keeps; a click every second for more than five hours.
    static let maximumCount = 20000

    var format = Self.formatName
    var version = Self.currentVersion
    /// The recorded area's width in pixels, for the aspect ratio the positions refer to.
    var width: Int
    /// The recorded area's height in pixels.
    var height: Int
    /// The movie's duration in seconds when the file was written.
    var duration: Double
    /// In time order.
    var clicks: [ClickRecord]

    init(width: Int, height: Int, duration: Double, clicks: [ClickRecord]) {
        self.width = width
        self.height = height
        self.duration = duration
        self.clicks = Self.cleaned(clicks)
    }

    /// `Movie.mp4` → `Movie.oriel-clicks.json`, in the same folder.
    static func url(for movie: URL) -> URL {
        let name = movie.deletingPathExtension().lastPathComponent + fileSuffix
        return movie.deletingLastPathComponent().appending(path: name, directoryHint: .notDirectory)
    }

    /// The sidecar next to `movie`, or nil when there is none. Throws when one exists but cannot be read.
    static func load(for movie: URL) throws -> ClickSidecar? {
        let url = url(for: movie)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try decode(Data(contentsOf: url))
    }

    /// Reads a click file, checking its format and version first, and drops clicks that are not usable.
    static func decode(_ data: Data) throws -> ClickSidecar {
        let decoder = JSONDecoder()
        let header: Header
        do {
            header = try decoder.decode(Header.self, from: data)
        } catch {
            throw ReadError.notAClickFile
        }
        guard header.format == formatName else { throw ReadError.notAClickFile }
        guard header.version <= currentVersion else { throw ReadError.unsupportedVersion(header.version) }
        var sidecar = try decoder.decode(ClickSidecar.self, from: data)
        sidecar.clicks = cleaned(sidecar.clicks)
        return sidecar
    }

    /// The file's contents: compact JSON with sorted keys, so the same clicks always give the same bytes.
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    /// Writes the sidecar next to `movie`, replacing an older one.
    func write(nextTo movie: URL) throws {
        try encoded().write(to: Self.url(for: movie), options: .atomic)
    }

    /// `write(nextTo:)`, off the main actor.
    @concurrent
    func save(nextTo movie: URL) async throws {
        try write(nextTo: movie)
    }

    /// `load(for:)`, off the main actor.
    @concurrent
    static func loadInBackground(for movie: URL) async throws -> ClickSidecar? {
        try load(for: movie)
    }

    /// The clicks inside `range`, moved so that `range.lowerBound` becomes 0: what a trimmed copy of the movie
    /// needs.
    func trimmed(to range: ClosedRange<Double>) -> ClickSidecar {
        let kept = clicks.compactMap { click -> ClickRecord? in
            guard range.contains(click.time) else { return nil }
            var moved = click
            moved.time = click.time - range.lowerBound
            return moved
        }
        return ClickSidecar(width: width, height: height, duration: range.upperBound - range.lowerBound, clicks: kept)
    }

    /// Valid clicks in time order, at most `maximumCount`.
    private static func cleaned(_ clicks: [ClickRecord]) -> [ClickRecord] {
        let valid = clicks.filter(\.isValid).sorted { $0.time < $1.time }
        return valid.count > maximumCount ? Array(valid.prefix(maximumCount)) : valid
    }

    /// Just enough to tell whether the rest can be read.
    private struct Header: Decodable {
        let format: String
        let version: Int
    }
}
