import Foundation

/// A node as an outline item: outlines keep their expansion and selection by item object, so each node keeps its box
/// for as long as the tree's indices stay the same.
final class NodeBox: NSObject {
    let node: Int32

    init(_ node: Int32) {
        self.node = node
    }
}
