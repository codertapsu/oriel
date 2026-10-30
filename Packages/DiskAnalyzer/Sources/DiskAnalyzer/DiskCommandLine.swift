import Foundation
import OrielCore

/// The CLI's `disk` verbs. Both only read: they list volumes, or scan a folder and report what takes its space.
enum DiskCommandLine {
    static let topRange = 1 ... 1000

    // MARK: disk volumes

    static func volumes(_ request: IPCRequest) async -> IPCResponse {
        let volumes = await Task.detached(priority: .userInitiated) { VolumeService.mountedVolumes() }.value
        guard request.flag("json") else {
            let lines = volumes.map { volume in
                let usage = volume.usage
                return "\(volume.name)  \(volume.path)  \(volume.format), \(volume.kind.rawValue): \(DiskFormat.bytes(usage.total)) total, "
                    + "\(DiskFormat.bytes(usage.used)) used, \(DiskFormat.bytes(usage.available)) free, "
                    + "\(DiskFormat.bytes(usage.purgeable)) purgeable"
            }
            return .ok(request, lines.joined(separator: "\n"))
        }
        let objects: [[String: Any]] = volumes.map { volume in
            [
                "name": volume.name, "path": volume.path, "format": volume.format, "kind": volume.kind.rawValue,
                "totalBytes": volume.usage.total, "usedBytes": volume.usage.used, "freeBytes": volume.usage.available,
                "purgeableBytes": volume.usage.purgeable, "availableIncludingPurgeableBytes": volume.usage.availableIncludingPurgeable,
                "readOnly": volume.isReadOnly, "ejectable": volume.canEject,
            ]
        }
        return json(request, objects)
    }

    // MARK: disk scan

    static func scan(_ request: IPCRequest, settings: SettingsStore) async -> IPCResponse {
        guard let argument = request.arguments.first else {
            return .failure(request, "disk scan needs a folder: oriel disk scan ~/Downloads", status: 64)
        }
        let home = NSHomeDirectory()
        guard argument.hasPrefix("/") || argument.hasPrefix("~") else {
            return .failure(request, "Give the folder as an absolute path or one starting with ~, such as ~/Downloads.", status: 64)
        }
        let path = ExclusionRules.normalize(argument, home: home)
        let top = request.options["top"].flatMap(Int.init) ?? 10
        guard topRange.contains(top) else {
            return .failure(request, "--top must be from \(topRange.lowerBound) to \(topRange.upperBound).", status: 64)
        }
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isFolder), isFolder.boolValue else {
            return .failure(request, "There is no folder at \(path).")
        }
        let found = await Task.detached(priority: .userInitiated) {
            (VolumeService.mountedVolumes(), VolumeService.firmlinks(), VolumeService.helperVolumeMounts())
        }.value
        let target = ScanTarget.resolve(
            path: path,
            volumes: found.0,
            dataVolumeExists: FileManager.default.fileExists(atPath: FirmlinkMap.dataVolume),
            firmlinks: found.1,
            macOSVolumes: settings[DiskSettings.countsMacOSFiles] ? MacOSVolumes.startup(helperMounts: found.2) : nil
        )
        let options = DiskSettings.scanOptions(in: settings, firmlinks: found.1)
        let outcome = await ScanEngine.scan(target, options: options, cancellation: CancellationFlag())
        var tree = outcome.tree
        var summary = outcome.summary
        if let volume = target.volume {
            tree = await Task.detached(priority: .userInitiated) { [tree] in
                DiskAnalyzerModel.addingVolumeBlocks(to: tree, volume: volume)
            }.value
        }
        // With Oriel's helper allowed, the folders only an administrator can open are read too; the CLI never asks for a
        // password.
        if summary.administratorFolders > 0, settings[DiskSettings.readsAsAdministrator], PrivilegedReader.status == .allowed {
            var nodes = tree.descendants(of: ScanTree.rootIndex) { $0.flags.contains(.needsAdministrator) }.sorted()
            if tree.root.flags.contains(.needsAdministrator) {
                nodes.insert(ScanTree.rootIndex, at: 0)
            }
            let folders = nodes.prefix(ElevatedRead.folderLimit).map(tree.path(of:))
            if case let .read(result) = await PrivilegedReader.read(ElevatedRead.Request(folders: folders, options: options)) {
                let volume = target.volume
                (tree, summary) = await Task.detached(priority: .userInitiated) { [tree, summary] in
                    DiskAnalyzerModel.adding(result, folders: folders, to: tree, summary: summary, volume: volume)
                }.value
            }
        }
        let report = ScanReport(tree: tree, summary: summary, target: target, top: top)
        return request.flag("json") ? json(request, report.json) : .ok(request, report.text)
    }

    static func json(_ request: IPCRequest, _ object: Any) -> IPCResponse {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else {
            return .failure(request, "The answer could not be written as JSON.")
        }
        return .ok(request, String(data: data, encoding: .utf8) ?? "{}")
    }
}
