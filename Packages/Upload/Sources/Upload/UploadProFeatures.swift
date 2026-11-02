import OrielCore

/// What only Oriel Pro unlocks in upload (PLAN §19): sending captures and recordings to a destination at all.
public extension ProFeature {
    nonisolated static let upload = ProFeature(
        id: "upload.destinations",
        title: "Upload",
        summary: "Send a capture or recording to S3, WebDAV, Dropbox, Google Drive or a shared folder and copy its link.",
        module: .capture
    )

    nonisolated static let uploadFeatures: [ProFeature] = [.upload]
}
