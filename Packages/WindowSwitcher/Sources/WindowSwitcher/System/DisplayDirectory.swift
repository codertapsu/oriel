import ApplicationServices
import CoreGraphics
import Foundation

/// The active displays, with the UUIDs SkyLight uses to name them.
nonisolated enum DisplayDirectory {
    static func current() -> [DisplayInfo] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).map { id in
            let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue()
            return DisplayInfo(id: id, uuid: uuid.flatMap { CFUUIDCreateString(nil, $0) as String? }, bounds: CGDisplayBounds(id))
        }
    }
}
