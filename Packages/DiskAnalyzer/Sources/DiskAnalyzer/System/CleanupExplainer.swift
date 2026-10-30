import Foundation
import FoundationModels
import OrielCore
import os

/// Apple Intelligence's reading of a folder Oriel's catalog does not know (PLAN §7.10 item 19): what it most likely is,
/// which app or tool made it, and whether removing it could lose what cannot be rebuilt. The on-device model reads the
/// facts Clean Up gathered (the path from the home folder, the names and sizes inside, the kinds of files, the signals),
/// never a file's contents, and nothing leaves the Mac. It can be wrong, so it never makes a folder look safer: when it
/// thinks something would be lost the advice turns careful, and otherwise it only explains. Hidden unless the model is
/// available on this Mac (`gate`) and Settings allows it (`disk.explainsFolders`).
nonisolated enum CleanupExplainer {
    struct Explanation: Sendable, Equatable {
        var text: String
        var owner: String?
        var mayLoseData: Bool
    }

    @Generable
    struct Reading {
        @Guide(
            description: "One or two plain sentences for the folder's owner: what the folder most likely is, and what removing it would do."
        )
        var description: String
        @Guide(description: "The app or tool that most likely made the folder, or an empty string when that is unclear.")
        var owner: String
        @Guide(
            description: "True when removing it could lose what cannot be downloaded or rebuilt: documents, settings, accounts or history."
        )
        var mayLoseData: Bool
    }

    private static let log = Log.logger("disk")

    static let instructions = """
    You help someone decide whether a folder on their Mac can be removed to free space. Use only the facts given. Say \
    what the folder most likely is and which app or tool made it. When you are not sure, say so. Never say a folder is \
    safe to remove when it could hold the person's own work, settings or accounts.
    """

    /// Open only when the system model is available: Apple silicon, Apple Intelligence on, the model downloaded.
    static var gate: FeatureGate {
        if case .available = SystemLanguageModel.default.availability {
            return .open
        }
        return .closed("Apple Intelligence isn't available on this Mac.")
    }

    static func explain(_ facts: CleanupFacts) async -> Explanation? {
        guard gate.isOpen else { return nil }
        let session = LanguageModelSession(instructions: instructions)
        do {
            let reading = try await session.respond(to: prompt(for: facts), generating: Reading.self).content
            let owner = reading.owner.trimmingCharacters(in: .whitespacesAndNewlines)
            return Explanation(text: reading.description, owner: owner.isEmpty ? nil : owner, mayLoseData: reading.mayLoseData)
        } catch {
            log.error("Apple Intelligence could not read a folder: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// The facts as the model reads them: names and numbers, the home folder as `~`.
    static func prompt(for facts: CleanupFacts) -> String {
        var lines = [
            "Folder: \(facts.homeRelativePath)",
            "Size: \(DiskFormat.bytes(facts.bytes)) in \(DiskFormat.count(facts.fileCount, "file")) and "
                + DiskFormat.count(facts.folderCount, "folder"),
        ]
        if let used = facts.lastUsed {
            lines.append("Last used: \(DiskFormat.relative(used))")
        }
        if !facts.children.isEmpty {
            lines.append("Largest items inside:")
            for child in facts.children.prefix(15) {
                lines.append("- \(child.name) (\(child.isFolder ? "folder" : "file"), \(DiskFormat.bytes(child.bytes)))")
            }
        }
        let kinds = facts.categories.filter { $0.value > 0 }.sorted { $0.value > $1.value }.prefix(4)
            .map { "\($0.key.title) \(DiskFormat.share($0.value, of: facts.bytes))" }
        if !kinds.isEmpty {
            lines.append("Kinds of files: " + kinds.joined(separator: ", "))
        }
        var signals: [String] = []
        if facts.isExcludedFromBackup {
            signals.append("its app keeps it out of Time Machine backups")
        }
        if facts.repositories > 0 {
            signals.append("it holds \(DiskFormat.count(facts.repositories, "Git repository", plural: "Git repositories"))")
        }
        if !facts.users.isEmpty {
            signals.append("in use now by " + Set(facts.users.map(\.name)).sorted().joined(separator: ", "))
        }
        if !signals.isEmpty {
            lines.append("Other facts: " + signals.joined(separator: "; "))
        }
        return lines.joined(separator: "\n")
    }
}
