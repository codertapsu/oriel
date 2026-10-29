import ApplicationServices

/// A window's Accessibility element as a history key. Two elements for the same window are equal (`CFEqual` compares
/// the process and the element), so the window is recognised however often it is looked up, without the private
/// `_AXUIElementGetWindow`.
nonisolated struct WindowIdentity: Hashable {
    let element: AXUIElement

    static func == (lhs: WindowIdentity, rhs: WindowIdentity) -> Bool {
        CFEqual(lhs.element, rhs.element)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(CFHash(element))
    }
}
