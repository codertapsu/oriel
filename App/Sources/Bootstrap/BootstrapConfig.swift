import Foundation
import OrielTranslation

/// The shared configuration a team drops in place (PLAN §7.7.5, docs/bootstrap.example.json): translation
/// providers, the default provider and the upload destination, secrets included. Imported once, then deleted.
struct BootstrapConfig: Codable, Equatable {
    struct Upload: Codable, Equatable {
        var kind: String
        var endpoint: String
        var region: String?
        var bucket: String
        var accessKey: String
        var secretKey: String?
        var publicBaseURL: String?
        var pathPrefix: String?
        var usesPathStyle: Bool?
    }

    var version: Int
    var providers: [BootstrapProvider]?
    var defaultProvider: String?
    var upload: Upload?
}
