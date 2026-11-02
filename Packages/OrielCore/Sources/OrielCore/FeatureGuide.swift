/// A page of the feature tour (PLAN §19): what a tool or feature does and how to start it, declared by the feature
/// itself, so a new tool brings its own page. The tour shows the current shortcut of `commandID`, runs it from Try It,
/// and marks the highlights that need Oriel Pro.
public struct FeatureGuide: Identifiable, Sendable {
    /// One thing the feature does.
    public struct Highlight: Identifiable, Sendable {
        public let title: String
        public let detail: String
        /// The Pro feature it describes, if any.
        public let proFeature: ProFeature?

        public var id: String {
            title
        }

        public init(_ title: String, _ detail: String, pro: ProFeature? = nil) {
            self.title = title
            self.detail = detail
            proFeature = pro
        }
    }

    public let id: String
    public let title: String
    /// An SF Symbol name.
    public let symbol: String
    public let summary: String
    public let highlights: [Highlight]
    /// The command or app action that Try It runs, and whose shortcut the page shows.
    public let commandID: String?
    /// What the feature needs from Privacy & Security.
    public let permissions: Set<PermissionKind>

    public init(
        id: String,
        title: String,
        symbol: String,
        summary: String,
        highlights: [Highlight],
        commandID: String? = nil,
        permissions: Set<PermissionKind> = []
    ) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.summary = summary
        self.highlights = highlights
        self.commandID = commandID
        self.permissions = permissions
    }
}
