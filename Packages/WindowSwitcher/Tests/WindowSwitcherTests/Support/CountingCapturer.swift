import CoreGraphics
import Foundation
import Synchronization
@testable import WindowSwitcher

/// Captures images that count themselves: `live` is how many are still in memory, so a test sees evicted thumbnails
/// being freed rather than only dropped from the cache's books.
actor CountingCapturer: WindowCapturing {
    nonisolated let live = Mutex(0)

    func prepare(windowIDs _: Set<UInt32>) {}

    func capture(windowID _: UInt32, pixelSize: CGSize) async -> CGImage? {
        image(width: Int(pixelSize.width), height: Int(pixelSize.height))
    }

    nonisolated var liveCount: Int {
        live.withLock { $0 }
    }

    /// A gray image whose pixels are freed, and the count lowered, when the last reference to it goes.
    private nonisolated func image(width: Int, height: Int) -> CGImage? {
        let bytesPerRow = width * 4
        let size = bytesPerRow * height
        guard size > 0, let space = CGColorSpace(name: CGColorSpace.sRGB), let pixels = malloc(size) else { return nil }
        memset(pixels, 0x80, size)
        let info = Unmanaged.passRetained(self).toOpaque()
        guard let provider = CGDataProvider(dataInfo: info, data: pixels, size: size, releaseData: { info, data, _ in
            free(UnsafeMutableRawPointer(mutating: data))
            if let info {
                Unmanaged<CountingCapturer>.fromOpaque(info).takeRetainedValue().live.withLock { $0 -= 1 }
            }
        }) else {
            free(pixels)
            Unmanaged<CountingCapturer>.fromOpaque(info).release()
            return nil
        }
        live.withLock { $0 += 1 }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }
}
