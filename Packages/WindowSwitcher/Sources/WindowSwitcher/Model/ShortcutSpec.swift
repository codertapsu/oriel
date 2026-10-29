import OrielCore

/// One of up to nine switcher shortcuts (PLAN §7.1.4): hold `holdModifiers`, press `nextKey` to open and step
/// forward, add `reverseModifier` to step back. Each shortcut has its own filter, grouping, release behaviour and
/// style; its filter and grouping together are its preset (`SwitcherPreset`).
///
/// Modifiers are `KeyCombo.Modifiers` rather than `CGEventFlags` (as the plan sketches it) because they are
/// Codable and are what `TapEvent` reports.
nonisolated struct ShortcutSpec: Codable, Sendable, Hashable {
    /// The plan's limit.
    static let maximumCount = 9

    /// The default shortcut: ⌥⇥, with ⇧ to go back.
    static let optionTab = ShortcutSpec(holdModifiers: .option, nextKey: KeyCode.tab, reverseModifier: .shift)

    var holdModifiers: KeyCombo.Modifiers
    var nextKey: UInt16
    var reverseModifier: KeyCombo.Modifiers?
    var filter: WindowFilter
    /// Most recent first, or each app's windows together.
    var grouping: WindowGrouping
    var releaseBehavior: ReleaseBehavior
    /// Overrides the global style for this shortcut.
    var style: DisplayStyle?
    var isEnabled: Bool

    init(
        holdModifiers: KeyCombo.Modifiers,
        nextKey: UInt16,
        reverseModifier: KeyCombo.Modifiers? = .shift,
        filter: WindowFilter = WindowFilter(),
        grouping: WindowGrouping = .ungrouped,
        releaseBehavior: ReleaseBehavior = .switchOnRelease,
        style: DisplayStyle? = nil,
        isEnabled: Bool = true
    ) {
        self.holdModifiers = holdModifiers
        self.nextKey = nextKey
        self.reverseModifier = reverseModifier
        self.filter = filter
        self.grouping = grouping
        self.releaseBehavior = releaseBehavior
        self.style = style
        self.isEnabled = isEnabled
    }

    /// Tolerates settings written by older builds: a missing field keeps its default. Shortcuts saved before grouping
    /// existed are ungrouped, so each keeps the preset its filter already amounts to.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        holdModifiers = try container.decode(KeyCombo.Modifiers.self, forKey: .holdModifiers)
        nextKey = try container.decode(UInt16.self, forKey: .nextKey)
        reverseModifier = try container.decodeIfPresent(KeyCombo.Modifiers.self, forKey: .reverseModifier)
        filter = try container.decodeIfPresent(WindowFilter.self, forKey: .filter) ?? WindowFilter()
        grouping = try container.decodeIfPresent(WindowGrouping.self, forKey: .grouping) ?? .ungrouped
        releaseBehavior = try container.decodeIfPresent(ReleaseBehavior.self, forKey: .releaseBehavior) ?? .switchOnRelease
        style = try container.decodeIfPresent(DisplayStyle.self, forKey: .style)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }

    /// What the shortcut shows, in one choice; nil when its filter and grouping are a custom mix. Setting a preset
    /// changes only the apps and screens filters and the grouping.
    var preset: SwitcherPreset? {
        get { SwitcherPreset(self) }
        set {
            if let newValue {
                self = newValue.applied(to: self)
            }
        }
    }

    /// The combination that opens the switcher and steps forward.
    var trigger: KeyCombo {
        get { KeyCombo(keyCode: nextKey, modifiers: holdModifiers) }
        set {
            nextKey = newValue.keyCode
            holdModifiers = newValue.modifiers
            self = normalized()
        }
    }

    /// The combination that opens the switcher and steps back, if the shortcut has one.
    var reverseTrigger: KeyCombo? {
        guard let reverse = effectiveReverseModifier else { return nil }
        return KeyCombo(keyCode: nextKey, modifiers: holdModifiers.union(reverse))
    }

    /// Whether a key press opens this shortcut, and in which direction. Modifiers must match exactly, so ⌥⇥
    /// never steals ⌥⌘⇥.
    func direction(keyCode: UInt16, modifiers: KeyCombo.Modifiers) -> SelectionDirection? {
        guard isEnabled, !holdModifiers.isEmpty, keyCode == nextKey else { return nil }
        if modifiers == holdModifiers {
            return .forward
        }
        if let reverse = effectiveReverseModifier, modifiers == holdModifiers.union(reverse) {
            return .backward
        }
        return nil
    }

    /// The reverse modifier without the bits the hold modifiers already contain; nil when nothing is left.
    var effectiveReverseModifier: KeyCombo.Modifiers? {
        guard let reverse = reverseModifier?.subtracting(holdModifiers), !reverse.isEmpty else { return nil }
        return reverse
    }

    /// The same shortcut with a reverse modifier that does not overlap the hold modifiers.
    func normalized() -> ShortcutSpec {
        var copy = self
        copy.reverseModifier = effectiveReverseModifier
        return copy
    }
}
