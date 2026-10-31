import Darwin
import Foundation

/// The processes that have files open in a folder or work in it (PLAN §7.10 item 19): each process's open files
/// (`PROC_PIDLISTFDS`, then `PROC_PIDFDVNODEPATHINFO`) and working folder (`PROC_PIDVNODEPATHINFO`). macOS answers for the
/// user's own processes, which are the ones that write to the user's folders; files a process only maps into memory are
/// not seen. Public libproc calls, made when Clean Up asks and again before anything goes.
nonisolated enum FolderUsers {
    /// A process using the folder, with the paths it has open there.
    struct Use: Sendable, Equatable {
        var pid: Int32
        var paths: [String]
    }

    /// The processes using `folder` or anything in it, but `excluded` (Oriel), with every path each has open there (a
    /// build daemon may hold thousands), spelled as `folder` is.
    static func uses(of folder: String, excluding excluded: Set<Int32> = []) -> [Use] {
        let spellings = spellings(of: folder)
        var uses: [Use] = []
        for pid in processes() where !excluded.contains(pid) {
            var paths: [String] = []
            for path in [workingFolder(of: pid)].compactMap(\.self) + openFiles(of: pid) {
                if let inside = respelled(path, from: spellings, to: folder) {
                    paths.append(inside)
                }
            }
            if !paths.isEmpty {
                uses.append(Use(pid: pid, paths: paths))
            }
        }
        return uses
    }

    /// How macOS may spell the folder: a path through the firmlinks may come back on the data volume, one through `/var`
    /// or `/tmp` with `/private` first, and one through a symbolic link (DerivedData moved to another disk) where it
    /// really is.
    static func spellings(of folder: String) -> [String] {
        let folder = folder.count > 1 && folder.hasSuffix("/") ? String(folder.dropLast()) : folder
        var spellings = variants(of: folder)
        if let real = realPath(folder), real != folder {
            spellings += variants(of: real).filter { !spellings.contains($0) }
        }
        return spellings
    }

    private static func variants(of folder: String) -> [String] {
        let data = FirmlinkMap.dataVolume
        var spellings = [folder, folder.hasPrefix(data + "/") ? String(folder.dropFirst(data.count)) : data + folder]
        if folder.hasPrefix("/private/") {
            spellings.append(String(folder.dropFirst("/private".count)))
        } else if ["/var/", "/tmp/", "/etc/"].contains(where: folder.hasPrefix) {
            spellings.append("/private" + folder)
        }
        return spellings
    }

    private static func realPath(_ path: String) -> String? {
        guard let resolved = realpath(path, nil) else { return nil }
        defer { free(resolved) }
        return String(cString: resolved)
    }

    /// `path` spelled from `folder`, when it is the folder or inside it under one of its spellings.
    static func respelled(_ path: String, from spellings: [String], to folder: String) -> String? {
        for spelling in spellings {
            if path == spelling {
                return folder
            }
            if path.hasPrefix(spelling + "/") {
                return folder + path.dropFirst(spelling.count)
            }
        }
        return nil
    }

    private static func processes() -> [Int32] {
        let needed = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard needed > 0 else { return [] }
        let stride = MemoryLayout<pid_t>.stride
        var pids = [pid_t](repeating: 0, count: Int(needed) / stride + 64)
        let used = pids.withUnsafeMutableBytes { proc_listpids(UInt32(PROC_ALL_PIDS), 0, $0.baseAddress, Int32($0.count)) }
        guard used > 0 else { return [] }
        return pids.prefix(Int(used) / stride).filter { $0 > 0 }
    }

    private static func workingFolder(of pid: Int32) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        let path = string(info.pvi_cdir.vip_path)
        return path.isEmpty ? nil : path
    }

    private static func openFiles(of pid: Int32) -> [String] {
        let needed = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard needed > 0 else { return [] }
        let stride = MemoryLayout<proc_fdinfo>.stride
        var descriptors = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(needed) / stride + 16)
        let used = descriptors.withUnsafeMutableBytes { proc_pidinfo(pid, PROC_PIDLISTFDS, 0, $0.baseAddress, Int32($0.count)) }
        guard used > 0 else { return [] }
        return descriptors.prefix(Int(used) / stride).compactMap { descriptor in
            guard Int32(descriptor.proc_fdtype) == PROX_FDTYPE_VNODE else { return nil }
            var info = vnode_fdinfowithpath()
            let size = Int32(MemoryLayout<vnode_fdinfowithpath>.size)
            guard proc_pidfdinfo(pid, descriptor.proc_fd, PROC_PIDFDVNODEPATHINFO, &info, size) == size else { return nil }
            let path = string(info.pvip.vip_path)
            return path.isEmpty ? nil : path
        }
    }

    /// A C string kept in a fixed-size array imported as a tuple.
    private static func string(_ tuple: some Any) -> String {
        withUnsafeBytes(of: tuple) { bytes in
            String(bytes: bytes.prefix { $0 != 0 }, encoding: .utf8) ?? ""
        }
    }
}
