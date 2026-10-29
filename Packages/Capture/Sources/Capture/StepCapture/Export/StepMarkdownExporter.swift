import Foundation
import SharedUI

/// Exports a step sequence as Markdown with its images in a folder beside it (PLAN §17): "Steps.md" and "Steps
/// images/step-01.png" onwards, linked relatively so the pair can be moved, committed or uploaded together. Notes keep
/// their line breaks and may use Markdown.
nonisolated enum StepMarkdownExporter {
    /// Writes `url` and the images folder next to it, which is emptied of earlier step images first. Returns the
    /// folder.
    @discardableResult
    static func export(_ items: [StepExportItem], title: String, subtitle: String, to url: URL) throws -> URL {
        let folderName = folderName(for: url)
        let folder = url.deletingLastPathComponent().appending(path: folderName, directoryHint: .isDirectory)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        for old in (try? fileManager.contentsOfDirectory(atPath: folder.path)) ?? [] where isStepImage(old) {
            try? fileManager.removeItem(at: folder.appending(path: old))
        }
        let names = items.map { fileName(for: $0.number, of: items.count) }
        for (item, name) in zip(items, names) {
            try autoreleasepool {
                guard let image = StepImageRenderer.image(for: item) else {
                    throw CaptureError.failed("The image of step \(item.number) could not be read.")
                }
                try ImageFile.write(image, to: folder.appending(path: name), format: .png, scale: item.scale)
            }
        }
        let text = markdown(items, title: title, subtitle: subtitle, folder: folderName, fileNames: names)
        try Data(text.utf8).write(to: url, options: .atomic)
        return folder
    }

    /// "Steps images" for "Steps.md".
    static func folderName(for url: URL) -> String {
        "\(url.deletingPathExtension().lastPathComponent) images"
    }

    /// "step-01.png"; three digits from 100 steps on.
    static func fileName(for number: Int, of count: Int) -> String {
        let digits = max(2, String(count).count)
        let padded = String(repeating: "0", count: max(0, digits - String(number).count)) + String(number)
        return "step-\(padded).png"
    }

    static func markdown(_ items: [StepExportItem], title: String, subtitle: String, folder: String, fileNames: [String]) -> String {
        var lines = ["# \(oneLine(title))", ""]
        if !subtitle.isEmpty {
            lines += ["_\(subtitle)_", ""]
        }
        for (item, name) in zip(items, fileNames) {
            let heading = oneLine(item.heading)
            lines += ["## \(item.number). \(heading)", ""]
            lines += ["![\(escapedAlt(heading))](\(link(folder: folder, file: name)))", ""]
            if !item.note.isEmpty {
                lines += [hardBreaks(item.note), ""]
            }
        }
        return lines.joined(separator: "\n")
    }

    /// The relative link, percent-encoded, so spaces and other characters in the folder's name work everywhere.
    static func link(folder: String, file: String) -> String {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "()"))
        let encode = { (part: String) in part.addingPercentEncoding(withAllowedCharacters: allowed) ?? part }
        return "\(encode(folder))/\(encode(file))"
    }

    private static func isStepImage(_ name: String) -> Bool {
        name.hasPrefix("step-") && name.hasSuffix(".png") && name.dropFirst(5).dropLast(4).allSatisfy(\.isNumber)
    }

    private static func oneLine(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline).joined(separator: " ")
    }

    private static func escapedAlt(_ text: String) -> String {
        text.replacing("\\", with: "\\\\").replacing("[", with: "\\[").replacing("]", with: "\\]")
    }

    /// Line breaks inside a paragraph kept as Markdown hard breaks; blank lines still separate paragraphs.
    private static func hardBreaks(_ text: String) -> String {
        text.components(separatedBy: "\n\n").map { paragraph in
            paragraph.split(separator: "\n", omittingEmptySubsequences: false).joined(separator: "  \n")
        }.joined(separator: "\n\n")
    }
}
