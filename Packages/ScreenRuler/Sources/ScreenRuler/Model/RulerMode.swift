/// What the ruler measures. Tab goes through them in this order, and 1, 2 and 3 pick one.
nonisolated enum RulerMode: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Drag a rectangle and read its size and position.
    case measureArea
    /// The distances from the pointer to the nearest edges on the screen, found in a still screenshot.
    case dimensions
    /// Horizontal and vertical guide lines, with the distances between them.
    case guides

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .measureArea: "Measure Area"
        case .dimensions: "Dimensions"
        case .guides: "Guides"
        }
    }

    /// The digit that switches to it.
    var number: Int {
        (Self.allCases.firstIndex(of: self) ?? 0) + 1
    }

    var next: RulerMode {
        let all = Self.allCases
        return all[((all.firstIndex(of: self) ?? 0) + 1) % all.count]
    }

    var previous: RulerMode {
        let all = Self.allCases
        return all[((all.firstIndex(of: self) ?? 0) + all.count - 1) % all.count]
    }
}
