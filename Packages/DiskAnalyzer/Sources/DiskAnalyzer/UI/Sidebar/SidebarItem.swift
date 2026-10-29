import Foundation

/// A row of the sidebar. Rows are kept by id across updates, so the outline keeps its selection and expansion.
final class SidebarItem: NSObject {
    enum Kind {
        case section(String)
        case volume(VolumeInfo)
        case cloud(CloudLocation)
        case record(ScanRecord)
    }

    let id: String
    var kind: Kind
    var children: [SidebarItem] = []

    init(id: String, kind: Kind) {
        self.id = id
        self.kind = kind
    }

    var isSection: Bool {
        if case .section = kind {
            return true
        }
        return false
    }

    var source: DiskSource? {
        switch kind {
        case .section: nil
        case let .volume(volume): .volume(volume.path)
        case let .cloud(location): .cloud(location.path)
        case let .record(record): .folder(record.rootPath)
        }
    }
}
