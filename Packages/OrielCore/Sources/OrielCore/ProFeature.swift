/// A capability only Oriel Pro unlocks (PLAN §19), declared once by the feature or tool that owns it, next to its
/// commands. The app lists every declared one in Settings → Oriel Pro and the feature tour, and asks `ProAccess`
/// before one runs. What is not declared is free.
public struct ProFeature: Hashable, Sendable, Identifiable {
    /// Stable and unique across the app, `<module>.<name>`.
    public let id: String
    public let title: String
    /// What it adds, in one sentence, for Settings → Oriel Pro and the feature tour.
    public let summary: String
    /// The tool or feature it belongs to; nil for the app's own, such as settings sync.
    public let module: ModuleID?

    public init(id: String, title: String, summary: String, module: ModuleID?) {
        self.id = id
        self.title = title
        self.summary = summary
        self.module = module
    }
}
