import SharedUI

/// The pasteboard types Clipboard History knows by name, and which of a copy's types it keeps.
nonisolated enum ClipboardTypes {
    static let plainText = PasteboardSnapshot.plainText
    static let utf16Text = "public.utf16-plain-text"
    static let utf16ExternalText = "public.utf16-external-plain-text"
    static let rtf = "public.rtf"
    static let rtfd = "com.apple.flat-rtfd"
    static let html = "public.html"
    static let url = "public.url"
    static let fileURL = "public.file-url"
    static let png = "public.png"
    static let tiff = "public.tiff"
    static let jpeg = "public.jpeg"
    static let heic = "public.heic"
    static let gif = "com.compuserve.gif"
    static let webP = "org.webmproject.webp"
    static let pdf = "com.adobe.pdf"
    static let color = "com.apple.cocoa.pasteboard.color"

    /// Image types, most preferred first.
    static let images = [png, tiff, jpeg, heic, gif, webP, pdf]

    /// Dropped from every copy: file promises and their metadata cannot be fulfilled once the app that made them has
    /// moved on, a web archive repeats the HTML with every image inside it, and the Universal Clipboard marker would
    /// mislabel a copy put back from the history.
    static let skipped: Set<String> = [
        "com.apple.webarchive",
        "com.apple.pasteboard.promised-file-url",
        "com.apple.pasteboard.promised-file-content-type",
        "com.apple.pasteboard.promised-file-name",
        "com.apple.pasteboard.promised-suggested-file-name",
        "com.apple.pasteboard.NSFilePromiseID",
        "com.apple.NSFilePromiseItemMetaData",
        "com.apple.is-remote-clipboard",
    ]

    /// The types worth keeping of one item, in its order. A file keeps only its URL and name; a PNG makes a TIFF of the
    /// same image redundant; promises, web archives and privacy markers go.
    static func kept(_ types: [String]) -> [String] {
        if types.contains(fileURL) {
            return types.filter { $0 == fileURL || $0 == plainText }
        }
        let hasPNG = types.contains(png)
        return types.filter { type in
            !skipped.contains(type) && !PrivacyFilter.markerTypes.contains(type) && !(hasPNG && type == tiff)
        }
    }

    /// `snapshot` with only the kept types of each item; items left with none are dropped.
    static func kept(_ snapshot: PasteboardSnapshot) -> PasteboardSnapshot {
        let items = snapshot.items.map { item in
            let types = Set(kept(item.map(\.type)))
            return item.filter { types.contains($0.type) }
        }
        return PasteboardSnapshot(items: items.filter { !$0.isEmpty })
    }
}
