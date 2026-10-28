import AppKit
import CoreGraphics

/// The file a dragged-out capture becomes (PLAN §7.2, item 6): named with the filename template, encoded only when
/// the drop target asks for it, on a background queue.
final nonisolated class PromisedImageFile: NSObject, NSFilePromiseProviderDelegate, Sendable {
    let image: CGImage
    let hdrImage: CGImage?
    let format: CaptureImageFormat
    let scale: CGFloat
    let fileName: String
    private let queue: OperationQueue

    init(image: CGImage, hdrImage: CGImage?, format: CaptureImageFormat, scale: CGFloat, baseName: String) {
        self.image = image
        self.hdrImage = hdrImage
        self.format = format
        self.scale = scale
        fileName = "\(baseName).\(format.fileExtension)"
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        self.queue = queue
    }

    /// The pasteboard writer for a drag.
    func makeProvider() -> NSFilePromiseProvider {
        NSFilePromiseProvider(fileType: format.type.identifier, delegate: self)
    }

    func filePromiseProvider(_: NSFilePromiseProvider, fileNameForType _: String) -> String {
        fileName
    }

    func filePromiseProvider(
        _: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler: @escaping @Sendable ((any Error)?) -> Void
    ) {
        let data = if format == .heic, let hdrImage {
            ImageEncoding.hdrHEICData(for: hdrImage, scale: scale)
        } else {
            ImageEncoding.data(for: image, format: format, scale: scale)
        }
        guard let data else {
            completionHandler(CaptureError.failed("The capture could not be encoded."))
            return
        }
        do {
            try data.write(to: url, options: .atomic)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    func operationQueue(for _: NSFilePromiseProvider) -> OperationQueue {
        queue
    }
}
