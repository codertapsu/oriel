import Foundation

/// Oriel's pages on the Codertapsu website (codertapsu-web), which App Store Connect links to as well (PLAN §19).
enum OrielLinks {
    static let base = URL(string: "https://codertapsu-web.web.app/oriel")!
    static let privacy = base.appending(path: "privacy")
    static let terms = base.appending(path: "terms")
    static let support = base.appending(path: "support")
}
