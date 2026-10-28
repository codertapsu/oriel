/// An `error` field in a provider's JSON that is either a string or an object with a `message`.
struct ServerMessage: Decodable, Sendable {
    let message: String?

    init(from decoder: any Decoder) throws {
        if let text = try? decoder.singleValueContainer().decode(String.self) {
            message = text
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }

    private enum CodingKeys: String, CodingKey {
        case message
    }
}
