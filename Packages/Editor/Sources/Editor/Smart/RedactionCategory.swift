/// What Smart Redact looks for (PLAN §17). The review lists what it found by category, each with a count and a
/// switch; links are off until the user turns them on, since most links in a screenshot are not private.
nonisolated enum RedactionCategory: String, CaseIterable, Sendable, Identifiable {
    case secret
    case cardNumber
    case iban
    case email
    case phone
    case ipAddress
    case link

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .secret: "Keys and tokens"
        case .cardNumber: "Card numbers"
        case .iban: "Bank accounts (IBAN)"
        case .email: "Email addresses"
        case .phone: "Phone numbers"
        case .ipAddress: "IP addresses"
        case .link: "Links"
        }
    }

    var symbolName: String {
        switch self {
        case .secret: "key"
        case .cardNumber: "creditcard"
        case .iban: "building.columns"
        case .email: "envelope"
        case .phone: "phone"
        case .ipAddress: "network"
        case .link: "link"
        }
    }

    var isOnByDefault: Bool {
        self != .link
    }

    /// Where two finds overlap, the more specific one (the lower number) wins: the digits of an IBAN are not also a
    /// card number, a card number is not also a phone number, and an email address is not also a link.
    var priority: Int {
        switch self {
        case .secret: 0
        case .iban: 1
        case .cardNumber: 2
        case .ipAddress: 3
        case .email: 4
        case .phone: 5
        case .link: 6
        }
    }

    static let defaultSelection = Set(allCases.filter(\.isOnByDefault))
}
