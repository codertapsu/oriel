import CoreGraphics
import PrivateAPIs

/// Reads Space layout and window membership through SkyLight (PLAN §7.1.1 item 3). Nil without the
/// symbols: the switcher then shows no Space badges and "current Space" means "listed by Accessibility".
nonisolated enum SpaceReader {
    static func snapshot(for windowIDs: [UInt32], displays: [DisplayInfo], apis: PrivateAPIs) -> SpaceSnapshot? {
        guard apis.canReadSpaces, let managed = apis.managedDisplaySpaces(), !managed.isEmpty else { return nil }
        let mapped = managed.map { display in
            SpaceSnapshot.Display(
                displayID: displayID(for: display.displayIdentifier, among: displays),
                currentSpaceID: display.currentSpaceID,
                spaceIDs: display.spaceIDs,
                fullScreenSpaceIDs: display.fullScreenSpaceIDs
            )
        }
        var windowSpaces: [UInt32: [UInt64]] = [:]
        for id in windowIDs {
            windowSpaces[id] = apis.spaceIDs(forWindow: id) ?? []
        }
        return SpaceSnapshot(displays: mapped, windowSpaces: windowSpaces)
    }

    /// SkyLight names displays by UUID. With "Displays have separate Spaces" off there is a single entry
    /// called `Main` that spans every display; it maps to a display only when there is just one, and windows
    /// are otherwise placed by their frames.
    static func displayID(for identifier: String, among displays: [DisplayInfo]) -> UInt32? {
        if identifier == "Main" {
            return displays.count == 1 ? displays[0].id : nil
        }
        return displays.first { $0.uuid?.caseInsensitiveCompare(identifier) == .orderedSame }?.id
    }
}
