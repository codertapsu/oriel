/// One row of the panel's list: a section heading or an item.
nonisolated enum ClipboardRow: Equatable, Sendable {
    case header(ClipboardSection)
    case item(ClipboardItem, ClipboardSection)

    var item: ClipboardItem? {
        if case let .item(item, _) = self {
            return item
        }
        return nil
    }
}
