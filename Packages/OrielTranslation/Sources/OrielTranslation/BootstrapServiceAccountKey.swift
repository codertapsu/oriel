import Foundation

/// A Google service account key in `bootstrap.json` (PLAN §7.7.5): the key file's JSON object pasted in as it is, or
/// that JSON as a string. Either way it is imported into the Keychain, never into settings.
public struct BootstrapServiceAccountKey: Codable, Sendable, Equatable {
    /// The key file's JSON text.
    public let json: String

    public init(json: String) {
        self.json = json
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            json = text
            return
        }
        // Every field of a key file is a string.
        let object = try container.decode([String: String].self)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
        guard let text = String(bytes: data, encoding: .utf8) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "The service account key isn't UTF-8.")
        }
        json = text
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(json)
    }
}
