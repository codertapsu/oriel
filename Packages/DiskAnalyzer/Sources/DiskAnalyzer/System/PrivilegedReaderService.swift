import Foundation

/// What the privileged helper does for Oriel, as root: lists folders by the scan's rules (`ElevatedRead.read`) and replies
/// with the listings. It reads directories and replies, nothing else.
final nonisolated class PrivilegedReaderService: NSObject, PrivilegedReading, Sendable {
    func readFolders(_ arguments: [String], reply: @escaping @Sendable (Data?, String?) -> Void) {
        guard let request = ElevatedRead.Request(arguments: arguments) else {
            reply(nil, "Oriel's helper did not understand the request.")
            return
        }
        let limited = ElevatedRead.Request(folders: Array(request.folders.prefix(ElevatedRead.folderLimit)), options: request.options)
        guard let data = try? JSONEncoder().encode(ElevatedRead.read(limited)) else {
            reply(nil, "Oriel's helper could not write what it read.")
            return
        }
        reply(data, nil)
    }
}
