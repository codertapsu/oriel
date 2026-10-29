import CoreGraphics

/// The fixed measurements of one display style, in points.
nonisolated struct LayoutMetrics: Sendable, Equatable {
    /// Inside the panel's edge.
    var padding: CGFloat
    /// Between tiles.
    var spacing: CGFloat
    var minimumTileWidth: CGFloat
    var maximumTileWidth: CGFloat
    /// Width over height of a tile's image area.
    var imageAspectRatio: CGFloat
    /// The title row under the image; for the list style, the whole row.
    var captionHeight: CGFloat
    /// The search field above the tiles, while a search is typed.
    var searchBarHeight: CGFloat
    /// The panel when nothing matches.
    var emptySize: CGSize
    /// An app's name in a grouped switcher: the band above each row of tiles, or the row above each group of titles.
    var groupHeaderHeight: CGFloat = 22
    /// The line of key hints under the tiles.
    var footerHeight: CGFloat = 26

    func tileHeight(forWidth width: CGFloat) -> CGFloat {
        (width / imageAspectRatio).rounded(.down) + captionHeight
    }

    /// Thumbnails: tiles between 120 points and the user's thumbnail size, 16:10 images.
    static func thumbnails(maximumTileWidth: CGFloat) -> LayoutMetrics {
        LayoutMetrics(
            padding: 16,
            spacing: 12,
            minimumTileWidth: 120,
            maximumTileWidth: max(120, maximumTileWidth),
            imageAspectRatio: 16 / 10,
            captionHeight: 26,
            searchBarHeight: 36,
            emptySize: CGSize(width: 360, height: 120)
        )
    }

    /// App icons: fixed tiles, like the system's Cmd-Tab.
    static let appIcons = LayoutMetrics(
        padding: 16,
        spacing: 10,
        minimumTileWidth: 104,
        maximumTileWidth: 104,
        imageAspectRatio: 104 / 80,
        captionHeight: 26,
        searchBarHeight: 36,
        emptySize: CGSize(width: 360, height: 120)
    )

    /// Titles: one column of rows, up to 600 points wide.
    static let titles = LayoutMetrics(
        padding: 8,
        spacing: 2,
        minimumTileWidth: 360,
        maximumTileWidth: 600,
        imageAspectRatio: 1,
        captionHeight: 30,
        searchBarHeight: 36,
        emptySize: CGSize(width: 360, height: 120),
        // A little taller than a grid's band: the header also separates one group's rows from the last.
        groupHeaderHeight: 26
    )

    static func forStyle(_ style: DisplayStyle, thumbnailWidth: CGFloat) -> LayoutMetrics {
        switch style {
        case .thumbnails: thumbnails(maximumTileWidth: thumbnailWidth)
        case .appIcons: appIcons
        case .titles: titles
        }
    }
}
