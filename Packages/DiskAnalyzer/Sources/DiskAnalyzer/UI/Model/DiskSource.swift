/// What the sidebar has selected: a volume, a cloud location, or a folder scanned before, each by path.
nonisolated enum DiskSource: Hashable, Sendable {
    case volume(String)
    case cloud(String)
    case folder(String)

    var path: String {
        switch self {
        case let .volume(path), let .cloud(path), let .folder(path): path
        }
    }
}
