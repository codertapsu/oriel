import CoreGraphics
import Testing
@testable import WindowSwitcher

/// The switcher's budget is 50 ms (p95) from the hotkey to the first frame (PLAN §9). The part that runs in the tap
/// callback is this model work — filter, rank, group, items, layout, labels and the first selection — and it must stay
/// a small slice of it, with every preset, even for 200 windows. Measured in the unoptimized test build, on a Mac that
/// may be busy, so the bound is generous; the optimized app is several times faster.
struct OpeningCostTests {
    /// 200 windows of 23 apps on two displays.
    private static let windows: [WindowEntry] = (0 ..< 200).map(window)

    private static func window(_ index: Int) -> WindowEntry {
        let app: Int = index % 23
        let display: UInt32 = index.isMultiple(of: 2) ? 1 : 2
        return Fixture.entry(
            UInt32(index + 1),
            pid: Int32(app + 1),
            app: "App \(app)",
            title: "Document \(index) — a long enough title to rank",
            display: display
        )
    }

    private static let context = FilterContext(activePID: 3, screenDisplayID: 1, displays: [FilterTests.main, FilterTests.left])

    /// Everything `SwitcherController` does synchronously when a shortcut opens.
    private func open(_ spec: ShortcutSpec, style: DisplayStyle, query: String = "") -> Int {
        let windows = spec.filter.apply(to: Self.windows, context: Self.context)
        let items = SwitcherItemBuilder.items(from: windows, style: style, query: query, grouping: spec.grouping)
        let grouped = spec.grouping == .byApp && style != .appIcons
        let groups = grouped ? SwitcherItemBuilder.groups(of: items) : []
        let layout = LayoutCalculator.layout(
            count: items.count, style: style, metrics: .forStyle(style, thumbnailWidth: 220),
            maximumSize: LayoutTests.laptop, showsSearchBar: !query.isEmpty,
            groupStarts: grouped ? groups.map(\.items.lowerBound) : nil, showsHints: true
        )
        let labels = layout.headerPlacements(for: groups.map(\.items))
        let start = grouped ? SwitcherItemBuilder.initialSelection(in: items, windows: windows) : nil
        return items.count + labels.count + (start?.forward ?? 0)
    }

    /// The 95th percentile of `runs` timings of `work`, nearest rank.
    private func p95(runs: Int = 40, _ work: (Int) -> Void) -> Duration {
        let clock = ContinuousClock()
        let samples = (0 ..< runs).map { run in clock.measure { work(run) } }.sorted()
        return samples[Int((Double(samples.count) * 0.95).rounded(.up)) - 1]
    }

    /// A shortcut opens with an empty search: this is all the model work before the first frame.
    @Test(arguments: SwitcherPreset.allCases)
    func openingStaysFarInsideTheBudget(_ preset: SwitcherPreset) {
        let spec = preset.applied(to: .optionTab)
        let styles: [DisplayStyle] = [.thumbnails, .titles, .appIcons]
        let time = p95 { run in
            #expect(open(spec, style: styles[run % styles.count]) > 0)
        }
        print("switcher opening, 200 windows, \(preset): p95 \(time)")
        #expect(time < .milliseconds(10), "p95 \(time) for \(preset)")
    }

    /// Each typed character ranks every window again; grouping the result adds a linear pass.
    @Test func searchingAGroupedListCostsAboutWhatSearchingDoes() {
        let grouped = SwitcherPreset.groupedByApp.applied(to: .optionTab)
        let plain = SwitcherPreset.allWindows.applied(to: .optionTab)
        let groupedTime = p95(runs: 20) { _ in _ = open(grouped, style: .thumbnails, query: "doc 1") }
        let plainTime = p95(runs: 20) { _ in _ = open(plain, style: .thumbnails, query: "doc 1") }
        print("switcher search, 200 windows: p95 \(plainTime), grouped \(groupedTime)")
        #expect(groupedTime < plainTime * 2 + .milliseconds(2))
    }
}
