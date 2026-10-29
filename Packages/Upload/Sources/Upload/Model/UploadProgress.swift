import Foundation

/// How far an upload is, for the progress panel.
public nonisolated struct UploadProgress: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case preparing
        case connecting
        case sending
        /// Asking for the link once the file is there (Dropbox, Google Drive).
        case finishing
    }

    public var phase: Phase
    public var sentBytes: Int64
    /// Nil when the destination cannot tell (sftp prints no progress in batch mode).
    public var totalBytes: Int64?

    public init(phase: Phase, sentBytes: Int64 = 0, totalBytes: Int64? = nil) {
        self.phase = phase
        self.sentBytes = sentBytes
        self.totalBytes = totalBytes
    }

    public static func sending(_ sent: Int64, of total: Int64?) -> UploadProgress {
        UploadProgress(phase: .sending, sentBytes: sent, totalBytes: total)
    }

    /// 0…1, or nil when unknown.
    public var fraction: Double? {
        guard phase == .sending, let totalBytes, totalBytes > 0 else { return phase == .finishing ? 1 : nil }
        return min(1, max(0, Double(sentBytes) / Double(totalBytes)))
    }

    /// "2.4 MB of 8.1 MB", "Connecting…".
    public var description: String {
        switch phase {
        case .preparing: "Preparing…"
        case .connecting: "Connecting…"
        case .finishing: "Getting the link…"
        case .sending:
            if let totalBytes, totalBytes > 0 {
                "\(Self.bytes(sentBytes)) of \(Self.bytes(totalBytes))"
            } else {
                "Sending…"
            }
        }
    }

    static func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }
}

/// Where an upload reports its progress; called from any thread.
public typealias UploadProgressHandler = @Sendable (UploadProgress) -> Void
