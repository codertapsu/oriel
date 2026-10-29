import Foundation

/// What a finished upload gives back.
public nonisolated struct UploadReceipt: Sendable, Equatable {
    /// The link to share.
    public var link: URL
    /// Where the file went below the destination's folder, after any renaming to avoid a name already there.
    public var path: [String]
    /// Something the user should know although the upload worked ("…could not be shared publicly").
    public var notice: String?
    /// Settings the upload learned and that should be kept: the Drive folder it made, a bookmark that moved.
    public var updatedTarget: UploadTarget?

    public init(link: URL, path: [String], notice: String? = nil, updatedTarget: UploadTarget? = nil) {
        self.link = link
        self.path = path
        self.notice = notice
        self.updatedTarget = updatedTarget
    }
}
