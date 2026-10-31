import AppKit
import SharedUI
import Testing
@testable import WindowSwitcher

/// A selection change redraws inside 8 ms (PLAN §9). Off screen this measures the main thread's part, with the tiles
/// in a window that is never shown: every tile's highlight is set as `SwitcherPanelController.select` sets it, AppKit's
/// display pass and the Core Animation commit run, and the two tiles that changed are drawn on the CPU, thumbnail and
/// title included. The window server's composite needs the screen and Instruments (checklist, Phase 9). The
/// unoptimized test build is measured, on a Mac that may be busy.
@MainActor
struct RedrawBudgetTests {
    private static let budget = Duration.milliseconds(8)
    private let plain = AccessibilityDisplay(reduceTransparency: false, increaseContrast: false, reduceMotion: false)

    /// Thumbnail tiles for `count` windows, placed as a session on a laptop's screen places them, in `window`.
    private func tiles(_ count: Int, in window: NSWindow) throws -> [WindowTileView] {
        let entries = (0 ..< count).map { index in
            Fixture.entry(UInt32(index + 1), pid: Int32(index % 23 + 1), app: "App \(index % 23)", title: "Document \(index)")
        }
        let items = SwitcherItemBuilder.items(from: entries, style: .thumbnails, query: "")
        let layout = LayoutCalculator.layout(
            count: items.count, style: .thumbnails, metrics: .forStyle(.thumbnails, thumbnailWidth: 220),
            maximumSize: LayoutTests.laptop, showsSearchBar: false, showsHints: true
        )
        let size = SwitcherPanelController.imageSize(of: layout, style: .thumbnails)
        let thumbnail = try #require(TestImage.make(width: Int(size.width * 2), height: Int(size.height * 2)))
        let content = SwitcherContentView()
        content.frame = CGRect(origin: .zero, size: layout.panelSize)
        window.setContentSize(layout.panelSize)
        window.contentView = content
        return items.enumerated().map { index, item in
            let tile = WindowTileView(frame: layout.frame(ofItem: index))
            content.grid.addSubview(tile)
            tile.configure(item, icon: nil, display: plain)
            tile.setThumbnail(thumbnail)
            return tile
        }
    }

    @Test(arguments: [60, 200])
    func aSelectionChangeRedrawsInsideTheBudget(_ count: Int) throws {
        let window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
        window.appearance = NSAppearance(named: .aqua)
        let tiles = try tiles(count, in: window)
        window.layoutIfNeeded()
        window.displayIfNeeded()
        let side = try #require(tiles.first?.bounds.size)
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: Int(side.width * 2), height: Int(side.height * 2), bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        // Tiles are flipped views; Core Animation draws with y up.
        context.translateBy(x: 0, y: side.height * 2)
        context.scaleBy(x: 2, y: -2)
        let clock = ContinuousClock()
        var selection = 0
        let samples = (0 ..< 41).map { _ in
            let previous = selection
            selection = (selection + 1) % tiles.count
            return clock.measure {
                for (position, tile) in tiles.enumerated() {
                    tile.isSelected = position == selection
                }
                window.displayIfNeeded()
                CATransaction.flush()
                for index in [previous, selection] {
                    tiles[index].layer?.render(in: context)
                }
            }
        }.dropFirst().sorted()
        let p95 = samples[Int((Double(samples.count) * 0.95).rounded(.up)) - 1]
        print("switcher selection change, \(count) tiles: median \(samples[samples.count / 2]), p95 \(p95)")
        #expect(p95 < Self.budget, "p95 \(p95) with \(count) tiles")
        window.contentView = nil
    }
}
