import Foundation

nonisolated extension Data {
    /// The bytes as text: UTF-8, or, for the rare message that is not valid UTF-8, Latin-1, which reads any bytes, so
    /// an error from sftp or a server is never lost.
    var utf8Text: String {
        String(bytes: self, encoding: .utf8) ?? String(bytes: self, encoding: .isoLatin1) ?? ""
    }
}
