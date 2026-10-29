import Foundation

/// A group of duplicates as an outline item, with its files as children.
final class DuplicateGroupItem: NSObject {
    let group: DuplicateGroup
    let files: [NodeBox]

    init(_ group: DuplicateGroup) {
        self.group = group
        files = group.files.map(NodeBox.init)
    }
}
