import Hotkeys
import OrielCore

/// The switcher's keyboard and gesture logic (PLAN §7.1.4), pure and unit-tested:
/// `idle → armed (hold modifiers down) → open(selection) → committing | cancelled`.
///
/// While open the tap consumes every key: Tab / the next key and Shift-Tab / the reverse modifier step, arrows
/// move (up and down by a row), typing searches, Delete edits the search, Esc clears it or cancels, Return
/// commits, Space commits while the search is empty, ⌥/⌘/⌃ with W, M, F, Q close, minimize, toggle full
/// screen or quit, and 1–9 jump to that item and switch. Releasing the hold modifiers commits unless the
/// session keeps open, which Sticky Keys forces (a latched modifier is released right after the next key).
/// Modifier changes are never consumed, so other apps never see a stuck modifier.
nonisolated struct SwitcherStateMachine: Sendable {
    nonisolated enum Phase: Sendable, Equatable {
        case idle
        /// The hold modifiers of at least one shortcut are down.
        case armed
        case open
        /// Until the next input: the controller is switching to the committed item.
        case committing
        /// Until the next input: the panel is closing without a switch.
        case cancelled
    }

    /// Where the selection starts in a list that is not in most-recent order (grouped by app): the indexes of the
    /// window used before the current one, for forward, and of the least recent one, for backward.
    nonisolated struct InitialSelection: Sendable, Equatable {
        var forward: Int
        var backward: Int
    }

    /// kVK_ANSI_KeypadEnter.
    private static let keypadEnter: UInt16 = 76

    var shortcuts: [ShortcutSpec]
    /// Read when a session opens; forces keep-open.
    var isStickyKeysOn = false
    /// The frontmost app takes the shortcuts itself (a VM or remote desktop on the exception list).
    var isSuppressed = false

    private(set) var phase: Phase = .idle
    private(set) var session: SwitcherSession?
    private(set) var itemCount = 0
    private(set) var columns = 1
    private var heldModifiers: KeyCombo.Modifiers = []
    /// Keys whose key-down was consumed: their key-up is consumed too, even after the panel closed.
    private var swallowedKeyUps: Set<UInt16> = []

    init(shortcuts: [ShortcutSpec] = [.optionTab]) {
        self.shortcuts = shortcuts
    }

    var isOpen: Bool {
        phase == .open
    }

    /// The selected item while open.
    var selection: Int? {
        isOpen ? session?.selection : nil
    }

    // MARK: Inputs

    mutating func handle(_ input: SwitcherInput) -> SwitcherTransition {
        settle()
        switch input {
        case let .keyDown(keyCode, modifiers, isRepeat, characters):
            if phase == .open {
                swallowedKeyUps.insert(keyCode)
                return .consume(openKeyDown(keyCode, modifiers: modifiers, isRepeat: isRepeat, characters: characters))
            }
            return closedKeyDown(keyCode, modifiers: modifiers, isRepeat: isRepeat)
        case let .keyUp(keyCode, _):
            if swallowedKeyUps.remove(keyCode) != nil || phase == .open {
                return .consume
            }
            return .pass
        case let .flagsChanged(modifiers):
            return .pass(flagsChanged(modifiers))
        case let .gesture(event):
            return .pass(gesture(event))
        }
    }

    /// Opens without a key press, in keep-open mode (menu item, `oriel debug open-switcher`).
    mutating func open(shortcutIndex: Int) -> [SwitcherEffect] {
        settle()
        guard phase != .open, shortcuts.indices.contains(shortcutIndex) else { return [] }
        return begin(SwitcherSession(
            shortcutIndex: shortcutIndex,
            holdModifiers: shortcuts[shortcutIndex].holdModifiers,
            keepsOpen: true,
            trigger: .programmatic
        ))
    }

    /// The controller's answer to `.show` and `.search`, and to window changes while open. `preferred`
    /// keeps a window selected across a re-rank; without it the selection is clamped. `initial` places the first
    /// selection in a list that is not most recent first; without it the second item (or the last) is selected.
    mutating func setItems(
        count: Int,
        columns: Int,
        selecting preferred: Int? = nil,
        initial: InitialSelection? = nil
    ) -> [SwitcherEffect] {
        itemCount = max(0, count)
        self.columns = max(1, columns)
        guard phase == .open, var session else { return [] }
        if let direction = session.initialDirection {
            let start = initial.map { direction == .forward ? $0.forward : $0.backward }
            session.selection = start.map(clamp) ?? Self.initialSelection(count: itemCount, direction: direction)
            session.initialDirection = nil
        } else {
            session.selection = clamp(preferred ?? session.selection)
        }
        self.session = session
        return [.select(session.selection)]
    }

    /// The pointer moved over item `index`.
    mutating func select(_ index: Int) -> [SwitcherEffect] {
        guard phase == .open, var session, (0 ..< itemCount).contains(index), index != session.selection else { return [] }
        session.selection = index
        self.session = session
        return [.select(index)]
    }

    /// Item `index` was clicked.
    mutating func commit(at index: Int) -> [SwitcherEffect] {
        guard phase == .open, var session, (0 ..< itemCount).contains(index) else { return [] }
        session.selection = index
        self.session = session
        return commitSession()
    }

    /// A click outside the panel, or the panel's screen went away.
    mutating func cancel() -> [SwitcherEffect] {
        guard phase == .open else { return [] }
        return cancelSession()
    }

    // MARK: Keys

    private mutating func closedKeyDown(_ keyCode: UInt16, modifiers: KeyCombo.Modifiers, isRepeat: Bool) -> SwitcherTransition {
        // A repeat of a key that was held through the last commit must not reopen the switcher.
        guard !isSuppressed, !isRepeat else { return .pass }
        for (index, spec) in shortcuts.enumerated() {
            guard let direction = spec.direction(keyCode: keyCode, modifiers: modifiers) else { continue }
            swallowedKeyUps.insert(keyCode)
            return .consume(begin(SwitcherSession(
                shortcutIndex: index,
                holdModifiers: spec.holdModifiers,
                keepsOpen: spec.releaseBehavior == .keepOpen || isStickyKeysOn,
                trigger: .keyboard,
                initialDirection: direction
            )))
        }
        return .pass
    }

    private mutating func openKeyDown(
        _ keyCode: UInt16,
        modifiers: KeyCombo.Modifiers,
        isRepeat: Bool,
        characters: String?
    ) -> [SwitcherEffect] {
        guard let session else { return [] }
        let spec = shortcuts.indices.contains(session.shortcutIndex) ? shortcuts[session.shortcutIndex] : nil
        if keyCode == KeyCode.tab || keyCode == spec?.nextKey {
            let reverse = spec?.effectiveReverseModifier.map { modifiers.isSuperset(of: $0) } ?? false
            return move(by: modifiers.contains(.shift) || reverse ? -1 : 1, wrapping: true)
        }
        if let navigation = navigate(keyCode, isRepeat: isRepeat) {
            return navigation
        }
        if !modifiers.isDisjoint(with: [.command, .option, .control]) {
            return isRepeat ? [] : command(keyCode)
        }
        if session.query.isEmpty, !isRepeat {
            if keyCode == KeyCode.space {
                return commitSession()
            }
            if let digit = KeyCode.digits.firstIndex(of: keyCode), !modifiers.contains(.shift) {
                return jump(to: digit)
            }
        }
        guard let characters, !characters.isEmpty else { return [] }
        return search(session.query + characters)
    }

    /// Esc, Return, arrows and Delete, which work with or without modifiers.
    private mutating func navigate(_ keyCode: UInt16, isRepeat: Bool) -> [SwitcherEffect]? {
        switch keyCode {
        case KeyCode.escape:
            guard !isRepeat, let session else { return [] }
            return session.query.isEmpty ? cancelSession() : search("")
        case KeyCode.returnKey, Self.keypadEnter:
            return isRepeat ? [] : commitSession()
        case KeyCode.leftArrow:
            return move(by: -1, wrapping: true)
        case KeyCode.rightArrow:
            return move(by: 1, wrapping: true)
        case KeyCode.upArrow:
            return move(by: -columns, wrapping: false)
        case KeyCode.downArrow:
            return move(by: columns, wrapping: false)
        case KeyCode.delete:
            guard let session, !session.query.isEmpty else { return [] }
            return search(String(session.query.dropLast()))
        default:
            return nil
        }
    }

    /// W, M, F, Q and the digits while a command modifier is down.
    private mutating func command(_ keyCode: UInt16) -> [SwitcherEffect] {
        guard let selection = session?.selection, itemCount > 0 else { return [] }
        switch keyCode {
        case KeyCode.ansiW: return [.act(.close, index: selection)]
        case KeyCode.ansiM: return [.act(.minimize, index: selection)]
        case KeyCode.ansiF: return [.act(.toggleFullScreen, index: selection)]
        case KeyCode.ansiQ: return [.quitApp(index: selection)]
        default: return KeyCode.digits.firstIndex(of: keyCode).map { jump(to: $0) } ?? []
        }
    }

    private mutating func flagsChanged(_ modifiers: KeyCombo.Modifiers) -> [SwitcherEffect] {
        heldModifiers = modifiers
        if phase == .open, let session, Self.releases(session, with: modifiers) {
            return commitSession()
        }
        if phase != .open {
            phase = isArmed(by: modifiers) ? .armed : .idle
        }
        return []
    }

    private mutating func gesture(_ event: GestureEvent) -> [SwitcherEffect] {
        switch event {
        case let .began(direction):
            if phase == .open {
                return move(by: direction.step, wrapping: true)
            }
            guard !isSuppressed, let index = shortcuts.firstIndex(where: \.isEnabled) else { return [] }
            return begin(SwitcherSession(
                shortcutIndex: index,
                holdModifiers: shortcuts[index].holdModifiers,
                keepsOpen: true,
                trigger: .gesture,
                initialDirection: direction
            ))
        case let .step(direction):
            return phase == .open ? move(by: direction.step, wrapping: true) : []
        case .ended:
            return phase == .open && session?.trigger == .gesture ? commitSession() : []
        case .cancelled:
            return phase == .open && session?.trigger == .gesture ? cancelSession() : []
        }
    }

    // MARK: Transitions

    private mutating func begin(_ session: SwitcherSession) -> [SwitcherEffect] {
        self.session = session
        phase = .open
        itemCount = 0
        return [.show(shortcutIndex: session.shortcutIndex)]
    }

    private mutating func commitSession() -> [SwitcherEffect] {
        guard let session, itemCount > 0 else { return cancelSession() }
        phase = .committing
        return [.commit(index: session.selection)]
    }

    private mutating func cancelSession() -> [SwitcherEffect] {
        phase = .cancelled
        return [.cancel]
    }

    /// Ends a finished session before the next input.
    private mutating func settle() {
        guard phase == .committing || phase == .cancelled else { return }
        session = nil
        phase = isArmed(by: heldModifiers) ? .armed : .idle
    }

    private mutating func move(by delta: Int, wrapping: Bool) -> [SwitcherEffect] {
        guard var session, itemCount > 0, delta != 0 else { return [] }
        var next = session.selection + delta
        if wrapping {
            next = ((next % itemCount) + itemCount) % itemCount
        } else if !(0 ..< itemCount).contains(next) {
            return []
        }
        guard next != session.selection else { return [] }
        session.selection = next
        self.session = session
        return [.select(next)]
    }

    private mutating func jump(to index: Int) -> [SwitcherEffect] {
        guard var session, index < itemCount else { return [] }
        session.selection = index
        self.session = session
        return [.select(index)] + commitSession()
    }

    private mutating func search(_ query: String) -> [SwitcherEffect] {
        guard var session, query != session.query else { return [] }
        session.query = query
        self.session = session
        return [.search(query)]
    }

    private func clamp(_ index: Int) -> Int {
        itemCount == 0 ? 0 : min(max(index, 0), itemCount - 1)
    }

    private func isArmed(by modifiers: KeyCombo.Modifiers) -> Bool {
        !isSuppressed && shortcuts.contains { $0.isEnabled && !$0.holdModifiers.isEmpty && modifiers.isSuperset(of: $0.holdModifiers) }
    }

    /// Whether `modifiers` let go of a keyboard session that switches on release.
    private static func releases(_ session: SwitcherSession, with modifiers: KeyCombo.Modifiers) -> Bool {
        session.trigger == .keyboard && !session.keepsOpen && !modifiers.isSuperset(of: session.holdModifiers)
    }

    /// Forward: the second item, which is the window used before the current one. Backward: the last item.
    static func initialSelection(count: Int, direction: SelectionDirection) -> Int {
        guard count > 0 else { return 0 }
        return direction == .forward ? min(1, count - 1) : count - 1
    }
}
