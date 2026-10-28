import AppKit

/// Fulfils a dragged file promise: names the file and writes the bytes computed when the drag began.
final class FilePromiseWriter: NSObject, NSFilePromiseProviderDelegate {
    private nonisolated let data: Data
    private let fileName: String

    init(data: Data, fileName: String) {
        self.data = data
        self.fileName = fileName
    }

    func filePromiseProvider(_: NSFilePromiseProvider, fileNameForType _: String) -> String {
        fileName
    }

    /// AppKit calls this off the main actor; it only touches the immutable bytes.
    nonisolated func filePromiseProvider(
        _: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler: @escaping (Error?) -> Void
    ) {
        do {
            try data.write(to: url, options: .atomic)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }
}
