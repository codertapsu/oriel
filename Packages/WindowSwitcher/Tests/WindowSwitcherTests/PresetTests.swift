import Foundation
import OrielCore
import Testing
@testable import WindowSwitcher

/// Switcher presets (PLAN §7.1.11): what each one sets, what it leaves, how it is stored, and how shortcuts saved before
/// presets existed come back.
struct PresetTests {
    @Test(arguments: [
        (SwitcherPreset.allWindows, WindowFilter.Apps.all, WindowFilter.Scope.all, WindowGrouping.ungrouped),
        (.activeApp, .active, .all, .ungrouped),
        (.groupedByApp, .all, .all, .byApp),
        (.currentDisplay, .all, .current, .ungrouped),
    ])
    func eachPresetSetsItsFiltersAndOrder(
        _ preset: SwitcherPreset,
        _ apps: WindowFilter.Apps,
        _ screens: WindowFilter.Scope,
        _ grouping: WindowGrouping
    ) {
        let spec = preset.applied(to: .optionTab)
        #expect(spec.filter.apps == apps && spec.filter.screens == screens && spec.grouping == grouping)
        #expect(spec.preset == preset)
    }

    @Test(arguments: SwitcherPreset.allCases)
    func aPresetKeepsTheOtherFiltersAndSettings(_ preset: SwitcherPreset) {
        var spec = ShortcutSpec(holdModifiers: .command, nextKey: KeyCode.grave, releaseBehavior: .keepOpen, style: .titles)
        spec.filter.spaces = .current
        spec.filter.minimized = .exclude
        spec.filter.hidden = .exclude
        spec.preset = preset
        #expect(spec.filter.spaces == .current && spec.filter.minimized == .exclude && spec.filter.hidden == .exclude)
        #expect(spec.holdModifiers == .command && spec.nextKey == KeyCode.grave)
        #expect(spec.releaseBehavior == .keepOpen && spec.style == .titles && spec.isEnabled)
    }

    @Test func mixesNoPresetNamesAreCustom() {
        let mixes = [
            ShortcutSpec(holdModifiers: .option, nextKey: KeyCode.tab, filter: WindowFilter(apps: .active, screens: .current)),
            ShortcutSpec(holdModifiers: .option, nextKey: KeyCode.tab, filter: WindowFilter(apps: .active), grouping: .byApp),
            ShortcutSpec(holdModifiers: .option, nextKey: KeyCode.tab, filter: WindowFilter(screens: .current), grouping: .byApp),
        ]
        for spec in mixes {
            #expect(spec.preset == nil)
        }
        // Choosing "Custom" itself changes nothing.
        var spec = mixes[0]
        spec.preset = nil
        #expect(spec == mixes[0])
    }

    @Test func thePresetIsStoredAsTheFiltersAndTheOrder() throws {
        let spec = SwitcherPreset.groupedByApp.applied(to: .optionTab)
        let data = try JSONEncoder().encode(spec)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains(#""grouping":"byApp""#))
        let decoded = try JSONDecoder().decode(ShortcutSpec.self, from: data)
        #expect(decoded == spec && decoded.preset == .groupedByApp)
    }

    /// Shortcuts exactly as the build before presets wrote them: no `grouping` key.
    private static let savedBeforePresets = """
    [
      {"holdModifiers":2,"nextKey":48,"reverseModifier":4,"isEnabled":true,"releaseBehavior":"switchOnRelease",
       "filter":{"apps":"all","spaces":"all","screens":"all","minimized":"include","hidden":"include"}},
      {"holdModifiers":2,"nextKey":50,"reverseModifier":4,"isEnabled":true,"releaseBehavior":"switchOnRelease",
       "filter":{"apps":"active","spaces":"all","screens":"all","minimized":"include","hidden":"include"}},
      {"holdModifiers":8,"nextKey":48,"isEnabled":false,"releaseBehavior":"keepOpen","style":"titles",
       "filter":{"apps":"all","spaces":"current","screens":"current","minimized":"exclude","hidden":"include"}},
      {"holdModifiers":1,"nextKey":48,"filter":{"apps":"active","screens":"current"}}
    ]
    """

    @Test func shortcutsSavedBeforePresetsShowThePresetTheyAmountTo() throws {
        let decoded = try JSONDecoder().decode([ShortcutSpec].self, from: Data(Self.savedBeforePresets.utf8))
        #expect(decoded.map(\.grouping) == [.ungrouped, .ungrouped, .ungrouped, .ungrouped])
        #expect(decoded.map(\.preset) == [.allWindows, .activeApp, .currentDisplay, nil])
        // Nothing else is lost on the way.
        #expect(decoded[2].filter.spaces == .current && decoded[2].filter.minimized == .exclude && !decoded[2].isEnabled)
        #expect(decoded[2].style == .titles && decoded[2].releaseBehavior == .keepOpen)
    }

    @MainActor
    @Test func theSettingsStoreLoadsOldShortcutsAndKeepsNewOnes() throws {
        let suite = "PresetTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data(Self.savedBeforePresets.utf8), forKey: SwitcherSettingKeys.shortcuts.name)
        let settings = SettingsStore(defaults: defaults)
        let loaded = SwitcherConfiguration.load(from: settings).shortcuts
        #expect(loaded.map(\.preset) == [.allWindows, .activeApp, .currentDisplay, nil])
        var changed = loaded
        changed[0].preset = .groupedByApp
        settings[SwitcherSettingKeys.shortcuts] = changed
        let reloaded = SwitcherConfiguration.load(from: SettingsStore(defaults: defaults)).shortcuts
        #expect(reloaded.map(\.preset) == [.groupedByApp, .activeApp, .currentDisplay, nil])
    }

    @MainActor
    @Test func theDefaultsAreAllWindowsWithHints() {
        let settings = SettingsStore(defaults: UserDefaults(suiteName: "PresetTests.defaults") ?? .standard)
        defer { UserDefaults.standard.removePersistentDomain(forName: "PresetTests.defaults") }
        let configuration = SwitcherConfiguration.load(from: settings)
        #expect(configuration.shortcuts.map(\.preset) == [.allWindows])
        #expect(configuration.showsKeyHints)
        #expect(SwitcherPreset.allCases.map(\.title) == [
            "All windows", "Active app's windows", "Windows grouped by app", "This display's windows",
        ])
    }

    // MARK: Filtering

    /// Safari (two windows), Notes and Mail on two displays; Notes is in front, the panel opens on display 1.
    private static let windows = [
        Fixture.entry(1, pid: 10, app: "Safari", title: "Apple", display: 1),
        Fixture.entry(2, pid: 20, app: "Notes", title: "Shopping", display: 1),
        Fixture.entry(3, pid: 10, app: "Safari", title: "GitHub", display: 2),
        Fixture.entry(4, pid: 30, app: "Mail", title: "Inbox", display: 2),
        Fixture.entry(5, pid: 20, app: "Notes", title: "Recipes", display: 1),
    ]
    private static let context = FilterContext(activePID: 20, screenDisplayID: 1, displays: [FilterTests.main, FilterTests.left])

    @Test(arguments: [
        (SwitcherPreset.allWindows, [UInt32]([1, 2, 3, 4, 5])),
        (.activeApp, [2, 5]),
        (.groupedByApp, [1, 3, 2, 5, 4]),
        (.currentDisplay, [1, 2, 5]),
    ])
    func eachPresetListsItsWindows(_ preset: SwitcherPreset, _ expected: [UInt32]) {
        let spec = preset.applied(to: .optionTab)
        let windows = spec.filter.apply(to: Self.windows, context: Self.context)
        let items = SwitcherItemBuilder.items(from: windows, style: .thumbnails, query: "", grouping: spec.grouping)
        #expect(items.map(\.id) == expected)
    }
}
