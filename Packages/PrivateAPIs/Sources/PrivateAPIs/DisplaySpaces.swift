/// The Spaces of one display, in Mission Control order, from `SLSCopyManagedDisplaySpaces`.
public struct DisplaySpaces: Sendable, Equatable {
    /// The display's UUID, or `Main` for the main display when "Displays have separate Spaces" is off.
    public let displayIdentifier: String
    public let currentSpaceID: UInt64
    public let spaceIDs: [UInt64]
    /// Spaces that hold a single full-screen app.
    public let fullScreenSpaceIDs: Set<UInt64>

    public init(displayIdentifier: String, currentSpaceID: UInt64, spaceIDs: [UInt64], fullScreenSpaceIDs: Set<UInt64>) {
        self.displayIdentifier = displayIdentifier
        self.currentSpaceID = currentSpaceID
        self.spaceIDs = spaceIDs
        self.fullScreenSpaceIDs = fullScreenSpaceIDs
    }

    /// 1-based position of `spaceID` on this display, as Mission Control numbers it.
    public func index(of spaceID: UInt64) -> Int? {
        spaceIDs.firstIndex(of: spaceID).map { $0 + 1 }
    }

    /// Parses the CFArray of dictionaries SkyLight returns. Unknown shapes yield an empty list, never a crash.
    static func parse(_ array: [Any]) -> [DisplaySpaces] {
        array.compactMap { item in
            guard let display = item as? [String: Any] else { return nil }
            let identifier = display["Display Identifier"] as? String ?? "?"
            let current = spaceID(display["Current Space"]) ?? 0
            let spaces = display["Spaces"] as? [Any] ?? []
            var ids: [UInt64] = []
            var fullScreen: Set<UInt64> = []
            for space in spaces {
                guard let id = spaceID(space) else { continue }
                ids.append(id)
                // type 4 is a full-screen (or tiled) app's own Space; 0 is a normal desktop.
                if let type = (space as? [String: Any])?["type"] as? Int, type == 4 {
                    fullScreen.insert(id)
                }
            }
            return DisplaySpaces(displayIdentifier: identifier, currentSpaceID: current, spaceIDs: ids, fullScreenSpaceIDs: fullScreen)
        }
    }

    private static func spaceID(_ value: Any?) -> UInt64? {
        guard let space = value as? [String: Any] else { return nil }
        if let id = space["id64"] as? UInt64 {
            return id
        }
        if let id = space["id64"] as? Int {
            return UInt64(id)
        }
        if let id = space["ManagedSpaceID"] as? Int {
            return UInt64(id)
        }
        return nil
    }
}

public extension DisplaySpaces {
    /// `parse`, exposed for tests with hand-built input.
    static func parseForTesting(_ array: [Any]) -> [DisplaySpaces] {
        parse(array)
    }
}
