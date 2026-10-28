import AVFoundation
import Foundation

// movie-info <movie>: the movie's duration, track counts and whether it plays, as JSON
// (scripts/verify-recording.sh).

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: movie-info <movie>\n".utf8))
    exit(64)
}

let asset = AVURLAsset(url: URL(fileURLWithPath: CommandLine.arguments[1]))
let (duration, isPlayable) = try await asset.load(.duration, .isPlayable)
let video = try await asset.loadTracks(withMediaType: .video)
let audio = try await asset.loadTracks(withMediaType: .audio)
let report: [String: Any] = [
    "duration": duration.seconds,
    "playable": isPlayable,
    "videoTracks": video.count,
    "audioTracks": audio.count,
]
let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
print(String(decoding: data, as: UTF8.self))
