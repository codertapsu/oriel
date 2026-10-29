import Foundation

/// The destinations in Settings order and which one Upload uses, kept as one setting (`UploadSettings.destinations`)
/// so removing the default and choosing another is a single write. Pure, so the S3 migration is tested.
public nonisolated struct UploadDestinationList: Codable, Sendable, Equatable {
    public var destinations: [UploadDestination]
    /// Nil, or a removed destination's ID: the first destination is the default.
    public var defaultID: UUID?

    /// The ID of the destination made from Oriel 0.1's single S3 setting. A bootstrap import still writes that setting,
    /// and each import updates this destination rather than adding another.
    public static let legacyID = UUID(uuid: (
        0x4F,
        0x52,
        0x49,
        0x45,
        0x4C,
        0x30,
        0x40,
        0x01,
        0x80,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x53
    ))

    public init(destinations: [UploadDestination] = [], defaultID: UUID? = nil) {
        self.destinations = destinations
        self.defaultID = defaultID
    }

    public var isEmpty: Bool {
        destinations.isEmpty
    }

    /// Where Upload sends files.
    public var defaultDestination: UploadDestination? {
        destinations.first { $0.id == defaultID } ?? destinations.first
    }

    public func destination(_ id: UUID) -> UploadDestination? {
        destinations.first { $0.id == id }
    }

    public func isDefault(_ id: UUID) -> Bool {
        defaultDestination?.id == id
    }

    /// Appends a destination of `kind` with a name no other destination has, and returns it.
    @discardableResult
    public mutating func add(_ kind: UploadDestinationKind) -> UploadDestination {
        let destination = UploadDestination(
            name: Self.uniqueName(kind.defaultName, among: destinations.map(\.displayName)),
            target: .empty(kind)
        )
        destinations.append(destination)
        return destination
    }

    public mutating func update(_ destination: UploadDestination) {
        guard let index = destinations.firstIndex(where: { $0.id == destination.id }) else { return }
        destinations[index] = destination
    }

    public mutating func remove(_ id: UUID) {
        destinations.removeAll { $0.id == id }
        if defaultID == id {
            defaultID = nil
        }
    }

    public mutating func makeDefault(_ id: UUID) {
        guard destination(id) != nil else { return }
        defaultID = id
    }

    /// Takes in Oriel 0.1's S3 setting: the first time as a new destination, which becomes the default when none was
    /// chosen, and afterwards by updating that destination's bucket settings, keeping the name, template and link format
    /// the user gave it. Returns the destination.
    @discardableResult
    public mutating func importLegacy(_ configuration: UploadConfiguration) -> UploadDestination {
        if var existing = destination(Self.legacyID), case .s3 = existing.target {
            existing.target = .s3(configuration)
            update(existing)
            return existing
        }
        remove(Self.legacyID)
        let host = URL(string: configuration.endpoint)?.host ?? ""
        let base = host.isEmpty ? UploadDestinationKind.s3.defaultName : host
        let destination = UploadDestination(
            id: Self.legacyID,
            name: Self.uniqueName(base, among: destinations.map(\.displayName)),
            target: .s3(configuration),
            nameTemplate: UploadNameTemplate.unguessable,
            stripsMetadata: configuration.stripsMetadata
        )
        destinations.insert(destination, at: 0)
        if defaultID.flatMap(self.destination) == nil {
            defaultID = destination.id
        }
        return destination
    }

    /// `base`, or `base 2`, `base 3`… when another destination has that name.
    static func uniqueName(_ base: String, among names: [String]) -> String {
        let taken = Set(names.map { $0.lowercased() })
        guard taken.contains(base.lowercased()) else { return base }
        var number = 2
        while taken.contains("\(base) \(number)".lowercased()) {
            number += 1
        }
        return "\(base) \(number)"
    }

    // MARK: Coding

    private enum CodingKeys: String, CodingKey {
        case destinations
        case defaultID = "defaultDestination"
    }

    /// Reads each destination on its own: one that cannot be read (a kind from a newer Oriel) is left out instead of
    /// taking every other destination with it.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var list = try container.nestedUnkeyedContainer(forKey: .destinations)
        var destinations: [UploadDestination] = []
        while !list.isAtEnd {
            if let destination = try? list.decode(UploadDestination.self) {
                destinations.append(destination)
            } else {
                _ = try? list.decode(Skipped.self)
            }
        }
        try self.init(destinations: destinations, defaultID: container.decodeIfPresent(UUID.self, forKey: .defaultID))
    }

    /// Consumes one element of any shape, reading nothing from it.
    private struct Skipped: Decodable {
        init(from _: any Decoder) {}
    }
}
