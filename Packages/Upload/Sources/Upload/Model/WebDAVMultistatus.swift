import Foundation

/// Reads a `207 Multi-Status` answer to a depth-0 `PROPFIND`: whether the address is a folder (its `resourcetype`
/// holds a `collection`) or a file. Namespaces are resolved, so `D:`, `d:` and unprefixed `DAV:` elements all count.
nonisolated enum WebDAVMultistatus {
    enum Resource: Equatable {
        case folder
        case file
        /// The answer did not say.
        case unknown
    }

    static func resource(in data: Data) -> Resource {
        let reader = Reader()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = reader
        guard parser.parse() else { return .unknown }
        if reader.sawCollection {
            return .folder
        }
        return reader.sawResourceType ? .file : .unknown
    }

    private final class Reader: NSObject, XMLParserDelegate {
        private(set) var sawResourceType = false
        private(set) var sawCollection = false
        private var depthInResourceType = 0

        func parser(
            _: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName _: String?,
            attributes _: [String: String] = [:]
        ) {
            guard namespaceURI == "DAV:" || namespaceURI == nil else { return }
            if elementName == "resourcetype" {
                sawResourceType = true
                depthInResourceType += 1
            } else if elementName == "collection", depthInResourceType > 0 {
                sawCollection = true
            }
        }

        func parser(_: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName _: String?) {
            if elementName == "resourcetype", namespaceURI == "DAV:" || namespaceURI == nil {
                depthInResourceType = max(0, depthInResourceType - 1)
            }
        }
    }
}
