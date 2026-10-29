import Darwin

/// The I/O rules for Oriel's scanning and hashing threads (`setiopolicy_np(3)`, per thread):
///
/// - No materializing: reading a file or folder that is only in the cloud (dataless) fails instead of making the
///   provider download it, so a scan never fills the disk with iCloud or Google Drive files, nor uses the network.
/// - No access-time updates: reading for a scan or a hash does not make files look recently used, which would spoil
///   Old Files.
nonisolated enum ScanIOPolicy {
    static func applyToCurrentThread() {
        setiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, IOPOL_SCOPE_THREAD, IOPOL_MATERIALIZE_DATALESS_FILES_OFF)
        setiopolicy_np(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_THREAD, IOPOL_ATIME_UPDATES_OFF)
    }
}
