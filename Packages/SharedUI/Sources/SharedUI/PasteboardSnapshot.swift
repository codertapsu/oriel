import Foundation

/// A pasteboard's contents as plain values: each item's representations in the order the writer offered them,
/// richest first. Clipboard History stores it, and Oriel announces its own copies with it.
public nonisolated struct PasteboardSnapshot: Codable, Sendable, Equatable {
    /// One representation of an item: a type identifier (a UTI) and its bytes.
    public struct Representation: Codable, Sendable, Equatable {
        public let type: String
        public let data: Data

        public init(type: String, data: Data) {
            self.type = type
            self.data = data
        }
    }

    public var items: [[Representation]]

    public init(items: [[Representation]]) {
        self.items = items
    }

    /// One item holding `text` as UTF-8 plain text.
    public init(text: String) {
        items = [[Representation(type: Self.plainText, data: Data(text.utf8))]]
    }

    public static let plainText = "public.utf8-plain-text"

    /// The bytes of the first item that has `type`.
    public func data(for type: String) -> Data? {
        for item in items {
            if let match = item.first(where: { $0.type == type }) {
                return match.data
            }
        }
        return nil
    }

    /// Every type on any item, each once, in the order first seen.
    public var types: [String] {
        var seen = Set<String>()
        return items.flatMap { $0.map(\.type) }.filter { seen.insert($0).inserted }
    }

    public var isEmpty: Bool {
        items.allSatisfy(\.isEmpty)
    }

    public var byteCount: Int {
        items.reduce(0) { total, item in item.reduce(total) { $0 + $1.data.count } }
    }
}
