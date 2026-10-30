import Darwin
import Foundation

/// Read as Administrator (PLAN §7.10): reads the folders of a scan that only their owner may open, macOS or another user,
/// which Full Disk Access does not change. As root, Oriel's own executable lists the folders by the scan's own rules
/// (`read`), either in Oriel's privileged helper once the user has allowed it (`PrivilegedReader`), or started through
/// macOS's password prompt in a mode that prints the listings as JSON (`runWithPassword`, `runIfRequested`). The
/// listings then go into the scan where the folders were (`apply`).
///
/// As root it reads and prints, nothing else: it opens no file, writes nothing, follows no symbolic link and ends when it
/// has printed. The password goes to macOS, never to Oriel. Folders System Integrity Protection guards stay unreadable
/// even so, and come back marked as protected by macOS.
public nonisolated enum ElevatedRead {
    /// The argument that starts the listing mode; Oriel checks for it first thing at launch.
    public static let argument = "--disk-read-folders"
    static let version = 1
    /// At most this many folders per run, which keeps the command short; a scan of a whole Mac has a few hundred.
    static let folderLimit = 2000

    /// What reading one folder gave.
    struct Listing: Codable, Sendable, Equatable {
        var path: String
        /// The error opening it gave; 0 when it was listed.
        var error: Int32 = 0
        /// Non-zero when the listing stopped part way.
        var partialError: Int32 = 0
        var digest: DirectoryDigest?
    }

    /// Everything the listing mode prints.
    struct Result: Codable, Sendable, Equatable {
        var version = ElevatedRead.version
        var listings: [Listing]
    }

    enum Outcome: Sendable, Equatable {
        case read(Result)
        /// The user cancelled the password prompt.
        case cancelled
        case failed(String)
    }

    /// What the listing mode is asked to read, and how.
    struct Request: Sendable, Equatable {
        var folders: [String]
        var options = ScanOptions()

        init(folders: [String], options: ScanOptions = ScanOptions()) {
            self.folders = folders
            self.options = options
        }

        /// From the arguments after `argument`: `--threshold <bytes>`, `--hidden`, `--cross`, `--exclude-name <name>` and
        /// `--exclude-path <path>` (repeated), then `--` and the folders, each an absolute path. Nil when they are wrong.
        init?(arguments: [String]) {
            var options = ScanOptions()
            options.includesHiddenFiles = false
            var names = Set<String>()
            var paths = Set<String>()
            var rest = arguments[...]
            while let argument = rest.popFirst(), argument != "--" {
                switch argument {
                case "--hidden": options.includesHiddenFiles = true
                case "--cross": options.crossesVolumes = true
                case "--threshold":
                    guard let value = rest.popFirst().flatMap(Int64.init), value > 0 else { return nil }
                    options.smallFileThreshold = value
                case "--exclude-name":
                    guard let name = rest.popFirst() else { return nil }
                    names.insert(name)
                case "--exclude-path":
                    guard let path = rest.popFirst() else { return nil }
                    paths.insert(path)
                default:
                    return nil
                }
            }
            options.exclusions = ExclusionRules(paths: paths, names: names)
            let folders = Array(rest)
            guard !folders.isEmpty, folders.allSatisfy({ $0.hasPrefix("/") }) else { return nil }
            self.init(folders: folders, options: options)
        }

        /// The arguments `init(arguments:)` reads back.
        var arguments: [String] {
            var arguments = ["--threshold", String(options.smallFileThreshold)]
            if options.includesHiddenFiles {
                arguments.append("--hidden")
            }
            if options.crossesVolumes {
                arguments.append("--cross")
            }
            for name in options.exclusions.names.sorted() {
                arguments += ["--exclude-name", name]
            }
            for path in options.exclusions.paths.sorted() {
                arguments += ["--exclude-path", path]
            }
            return arguments + ["--"] + folders
        }
    }

    // MARK: In Oriel

    /// Lists the request's folders as root, through macOS's password prompt. `executable` is Oriel's own.
    static func runWithPassword(_ request: Request, executable: String) async -> Outcome {
        let count = DiskFormat.count(request.folders.count, "folder")
        let script = AdminCommand.appleScript(
            for: [executable, argument] + request.arguments,
            prompt: "Oriel wants to read \(count) that only an administrator can open, to count the space they take. It changes nothing."
        )
        let result = await ProcessRunner.run(AdminCommand.osascript, ["-e", script])
        if result.succeeded {
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let decoded = try? JSONDecoder().decode(Result.self, from: Data(output.utf8)), decoded.version == version else {
                return .failed("Oriel could not make sense of what the folders gave.")
            }
            return .read(decoded)
        }
        // osascript reports the user's Cancel as error -128.
        if result.error.contains("-128") {
            return .cancelled
        }
        return .failed(result.error.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Puts what was read into `tree` at `folders`, the folders it was asked for, counting as a scan counts, marks what it
    /// added `readAsAdministrator` (and `macOSVolume` below a folder of macOS's), and adds the digests to `summary`. A
    /// folder still unreadable takes the reason root got. Returns the folders whose totals must be summed again.
    static func apply(_ result: Result, folders: [String], to tree: inout ScanTree, summary: inout ScanSummary) -> Set<Int32> {
        let listings = Dictionary(result.listings.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        var dirty = Set<Int32>()
        var stack: [(node: Int32, path: String)] = folders.compactMap { path in
            // Only folders still waiting for an administrator: an edit since may have taken one out.
            guard let node = tree.index(ofPath: path), tree[node].flags.contains(.needsAdministrator) else { return nil }
            return (node, path)
        }
        while let (node, path) = stack.popLast() {
            guard let listing = listings[path] else { continue }
            guard listing.error == 0, var digest = listing.digest else {
                if listing.error == ENOENT {
                    tree.removeFlags(UnreadableReason.allFlags, at: node)
                } else {
                    tree.setUnreadable(UnreadableReason(error: listing.error), at: node)
                }
                continue
            }
            let added = tree[node].flags.intersection(.macOSVolume).union(.readAsAdministrator)
            for index in digest.items.indices {
                digest.items[index].flags.formUnion(added)
            }
            tree.removeFlags(UnreadableReason.allFlags.union(.partial), at: node)
            tree.insertFlags(listing.partialError == 0 ? added : added.union(.partial), at: node)
            summary.absorb(digest)
            dirty.insert(node)
            for (child, item) in tree.merge(digest, into: node) {
                stack.append((child, DirectoryDigest.childPath(path, item.name)))
            }
        }
        return dirty
    }

    // MARK: As root

    /// Runs the listing mode when Oriel was started with `argument` first, and returns its exit status; nil otherwise, so
    /// Oriel starts as usual. It prints the listings to standard output and nothing else.
    public static func runIfRequested(_ arguments: [String]) -> Int32? {
        guard arguments.count > 1, arguments[1] == argument else { return nil }
        guard let request = Request(arguments: Array(arguments.dropFirst(2))) else {
            let usage = "usage: Oriel \(argument) [--threshold <bytes>] [--hidden] [--cross] [--exclude-name <name>]… "
                + "[--exclude-path <path>]… -- <folder>…\n"
            FileHandle.standardError.write(Data(usage.utf8))
            return 64
        }
        guard let data = try? JSONEncoder().encode(read(request)) else { return 70 }
        FileHandle.standardOutput.write(data)
        return 0
    }

    /// Lists the folders and every folder below them the scan's rules enter, depth first, with the scan's own reader,
    /// counting (`DirectoryDigest`) and I/O rules (`ScanIOPolicy`: no downloads of cloud files, no access times).
    static func read(_ request: Request) -> Result {
        ScanIOPolicy.applyToCurrentThread()
        let reader = DirectoryReader()
        var categories = FileCategoryCache()
        var links = HardLinkRegistry()
        var listings: [Listing] = []
        var stack: [(path: String, inherited: FileCategory?)] = request.folders.reversed().map { ($0, nil) }
        while let (path, inherited) = stack.popLast() {
            switch reader.read(path) {
            case let .unreadable(error):
                listings.append(Listing(path: path, error: error))
            case let .listed(entries, error):
                let digest = DirectoryDigest.make(
                    entries: entries,
                    parentPath: path,
                    inheritedCategory: inherited,
                    options: request.options,
                    categories: &categories,
                    isFirstLink: { links.isFirstLink(device: $0, inode: $1) },
                    canCrossInto: MountCheck.canCross
                )
                listings.append(Listing(path: path, partialError: error, digest: digest))
                for item in digest.items.reversed() where item.descends {
                    stack.append((DirectoryDigest.childPath(path, item.name), item.inheritedCategory))
                }
            }
        }
        return Result(listings: listings)
    }
}
