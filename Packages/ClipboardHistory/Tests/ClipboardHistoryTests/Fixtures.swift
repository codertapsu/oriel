import AppKit
@testable import ClipboardHistory
import CoreGraphics
import Foundation
import SharedUI

/// Items, snapshots and images for the tests.
enum Fixtures {
    static func item(
        _ text: String,
        kind: ClipboardKind = .text,
        hash: String? = nil,
        date: Date = Date(),
        source: String? = "Notes"
    ) -> ClipboardItem {
        let classification = ClipboardClassifier.Result(kind: kind, title: text, text: text, contentHash: hash ?? "hash-\(text)")
        return ClipboardItem(
            classification: classification,
            byteCount: text.utf8.count,
            sourceName: source,
            sourceBundleID: source.map { "com.example.\($0.lowercased())" },
            date: date
        )
    }

    static func snapshot(_ representations: [(String, Data)]) -> PasteboardSnapshot {
        PasteboardSnapshot(items: [representations.map { PasteboardSnapshot.Representation(type: $0.0, data: $0.1) }])
    }

    static func text(_ string: String) -> PasteboardSnapshot {
        PasteboardSnapshot(text: string)
    }

    /// A PNG of the given size, half red and half blue.
    static func png(width: Int = 40, height: Int = 30) throws -> Data {
        let image = try cgImage(width: width, height: height)
        guard let data = ImageFile.data(for: image, format: .png) else { throw CocoaError(.fileWriteUnknown) }
        return data
    }

    static func cgImage(width: Int, height: Int) throws -> CGImage {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { throw CocoaError(.featureUnsupported) }
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        guard let image = context.makeImage() else { throw CocoaError(.featureUnsupported) }
        return image
    }

    static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "oriel-clipboard-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func data(_ string: String) -> Data {
        Data(string.utf8)
    }
}
