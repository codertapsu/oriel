import Darwin

/// Copies a file or a folder with `copyfile(3)`: recursively, with metadata and extended attributes, never following
/// symbolic links, and as an APFS clone where source and destination share a volume, which takes no time and no
/// space. The status callback reports the bytes written and stops the copy when it is cancelled.
///
/// One copy at a time, on the thread that calls `copy`.
final nonisolated class FileCopier {
    struct Failure: Error, Sendable {
        var path: String
        var code: Int32
    }

    private let cancellation: CancellationFlag
    private let report: (Int64) -> Void
    /// Bytes of the files finished so far, across every `copy` call.
    private(set) var copiedBytes: Int64 = 0
    private var currentFile: Int64 = 0
    private var failure: Failure?

    /// `report` gets the bytes copied so far, after each write.
    init(cancellation: CancellationFlag, report: @escaping (Int64) -> Void) {
        self.cancellation = cancellation
        self.report = report
    }

    /// Copies `source` to `destination`, which must not exist yet.
    func copy(_ source: String, to destination: String) throws(Failure) {
        failure = nil
        currentFile = 0
        guard let state = copyfile_state_alloc() else { throw Failure(path: source, code: ENOMEM) }
        defer { copyfile_state_free(state) }
        let callback: copyfile_callback_t = { what, stage, state, source, _, context in
            guard let context else { return COPYFILE_CONTINUE }
            return Unmanaged<FileCopier>.fromOpaque(context).takeUnretainedValue().handle(what, stage, state, source)
        }
        copyfile_state_set(state, UInt32(COPYFILE_STATE_STATUS_CB), unsafeBitCast(callback, to: UnsafeRawPointer.self))
        copyfile_state_set(state, UInt32(COPYFILE_STATE_STATUS_CTX), Unmanaged.passUnretained(self).toOpaque())
        let flags = COPYFILE_CLONE | COPYFILE_ALL | COPYFILE_RECURSIVE | COPYFILE_NOFOLLOW | COPYFILE_EXCL
        let result = copyfile(source, destination, state, copyfile_flags_t(flags))
        let code = errno
        if cancellation.isCancelled {
            throw Failure(path: source, code: ECANCELED)
        }
        if let failure {
            throw failure
        }
        if result != 0 {
            throw Failure(path: source, code: code == 0 ? EIO : code)
        }
    }

    private func handle(_ what: Int32, _ stage: Int32, _ state: copyfile_state_t?, _ source: UnsafePointer<CChar>?) -> Int32 {
        if cancellation.isCancelled {
            return COPYFILE_QUIT
        }
        if stage == COPYFILE_ERR {
            failure = Failure(path: source.map { String(cString: $0) } ?? "", code: errno)
            return COPYFILE_QUIT
        }
        if what == COPYFILE_COPY_DATA, stage == COPYFILE_PROGRESS {
            var copied: off_t = 0
            if let state, copyfile_state_get(state, UInt32(COPYFILE_STATE_COPIED), &copied) == 0 {
                currentFile = Int64(copied)
                report(copiedBytes + currentFile)
            }
        } else if what == COPYFILE_RECURSE_FILE, stage == COPYFILE_FINISH {
            var size = currentFile
            var info = stat()
            // A clone writes no data, so there was no progress: count the file's length.
            if size == 0, let source, lstat(source, &info) == 0 {
                size = Int64(info.st_size)
            }
            copiedBytes += size
            currentFile = 0
            report(copiedBytes)
        }
        return COPYFILE_CONTINUE
    }
}
