import CoreGraphics
import Foundation
import SharedUI

/// Exports a step sequence as one self-contained HTML file (PLAN §17): the images are embedded as PNG data, so the
/// file opens anywhere and can be mailed on its own. It follows the reader's light or dark appearance and prints one
/// step after another.
nonisolated enum StepHTMLExporter {
    /// One step ready for the page: its PNG and its size in points.
    struct Page {
        let item: StepExportItem
        let png: Data
        let size: CGSize
    }

    static func export(_ items: [StepExportItem], title: String, subtitle: String, accent: CGColor, to url: URL) throws {
        var pages: [Page] = []
        for item in items {
            try autoreleasepool {
                guard let image = StepImageRenderer.image(for: item),
                      let png = ImageFile.data(for: image, format: .png, scale: item.scale)
                else {
                    throw CaptureError.failed("The image of step \(item.number) could not be read.")
                }
                pages.append(Page(item: item, png: png, size: item.pointSize))
            }
        }
        let text = html(pages, title: title, subtitle: subtitle, accent: hex(accent))
        try Data(text.utf8).write(to: url, options: .atomic)
    }

    static func html(_ pages: [Page], title: String, subtitle: String, accent: String) -> String {
        var body = ""
        for page in pages {
            let item = page.item
            let heading = escape(item.heading)
            body += """
            <section class="step" id="step-\(item.number)">
              <h2><span class="number">\(item.number)</span><span class="heading">\(heading)</span></h2>

            """
            if !item.note.isEmpty {
                body += "  <p class=\"note\">\(escape(item.note).replacing("\n", with: "<br>"))</p>\n"
            }
            let width = Int(page.size.width.rounded())
            let height = Int(page.size.height.rounded())
            body += """
              <img src="data:image/png;base64,\(page.png.base64EncodedString())" width="\(width)" height="\(height)" alt="\(heading)">
            </section>

            """
        }
        let meta = subtitle.isEmpty ? "" : "<p class=\"meta\">\(escape(subtitle))</p>\n"
        return """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="generator" content="Oriel">
        <title>\(escape(title))</title>
        <style>
        :root { color-scheme: light dark; --accent: \(accent);
          --text: #1c1c1e; --secondary: #6c6c70; --line: #d8d8dc; --page: #ffffff; }
        @media (prefers-color-scheme: dark) {
          :root { --text: #f2f2f7; --secondary: #a1a1a6; --line: #3a3a3c; --page: #1c1c1e; }
        }
        body { margin: 0; background: var(--page); color: var(--text);
          font: 15px/1.5 -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; }
        main { max-width: 1040px; margin: 0 auto; padding: 40px 24px 64px; }
        h1 { font-size: 28px; margin: 0 0 4px; }
        .meta { color: var(--secondary); margin: 0 0 32px; }
        .step { margin: 0 0 48px; break-inside: avoid; }
        h2 { display: flex; align-items: center; gap: 12px; font-size: 18px; margin: 0 0 6px; }
        .number { flex: none; display: grid; place-items: center; width: 28px; height: 28px;
          border-radius: 50%; background: var(--accent); color: #fff; font-size: 14px; }
        .note { color: var(--secondary); margin: 0 0 12px 40px; }
        img { display: block; max-width: 100%; height: auto; margin-top: 12px;
          border: 1px solid var(--line); border-radius: 6px; }
        </style>
        </head>
        <body>
        <main>
        <h1>\(escape(title))</h1>
        \(meta)\(body)</main>
        </body>
        </html>

        """
    }

    /// Text safe in HTML content and attributes.
    static func escape(_ text: String) -> String {
        var escaped = ""
        for character in text {
            switch character {
            case "&": escaped += "&amp;"
            case "<": escaped += "&lt;"
            case ">": escaped += "&gt;"
            case "\"": escaped += "&quot;"
            case "'": escaped += "&#39;"
            default: escaped.append(character)
            }
        }
        return escaped
    }

    /// "#0A84FF" for an sRGB colour.
    static func hex(_ color: CGColor) -> String {
        let srgb = CGColorSpace(name: CGColorSpace.sRGB).flatMap { color.converted(to: $0, intent: .defaultIntent, options: nil) } ?? color
        let components = srgb.components ?? []
        let channels = components.count >= 3 ? Array(components.prefix(3)) : Array(repeating: components.first ?? 0, count: 3)
        return "#" + channels.map { String(format: "%02X", Int((min(max($0, 0), 1) * 255).rounded())) }.joined()
    }
}
