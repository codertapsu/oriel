import OrielCore

public extension FeatureGuide {
    /// Upload's page in the feature tour (PLAN §19).
    nonisolated static let upload = FeatureGuide(
        id: "upload",
        title: "Upload",
        symbol: "icloud.and.arrow.up",
        summary: "Send a capture to storage of your own and copy its link, from Quick Access, the editor or Instant "
            + "Capture.",
        highlights: [
            Highlight(
                "Your storage",
                Sandbox.isActive
                    ? "S3-compatible storage, WebDAV, Dropbox, Google Drive or a shared folder."
                    : "S3-compatible storage, WebDAV, SFTP, Dropbox, Google Drive or a shared folder.",
                pro: .upload
            ),
            Highlight("Links your way", "Choose the file name, and copy the link alone, as Markdown or as HTML.", pro: .upload),
            Highlight("Kept safe", "Passwords, keys and sign-ins stay in your keychain."),
        ]
    )
}
