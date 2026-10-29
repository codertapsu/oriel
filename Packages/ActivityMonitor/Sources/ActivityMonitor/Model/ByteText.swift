import Foundation

/// Text from the bytes the kernel and the tools hand back. Names and paths are UTF-8 in practice; anything else is read
/// as Latin-1, which accepts every byte, so a name never comes back empty.
nonisolated enum ByteText {
    static func string(_ bytes: some Sequence<UInt8>) -> String {
        let array = Array(bytes)
        return String(bytes: array, encoding: .utf8) ?? String(bytes: array, encoding: .isoLatin1) ?? ""
    }

    /// The bytes up to the first NUL, as C strings end.
    static func cString(_ bytes: some Sequence<UInt8>) -> String {
        string(bytes.prefix { $0 != 0 })
    }

    /// A fixed-size C string field, such as `p_comm` or `vip_path`.
    static func cString(of field: some Any) -> String {
        withUnsafeBytes(of: field) { cString($0) }
    }

    /// A `[CChar]` buffer filled by a C call.
    static func cString(_ buffer: [CChar]) -> String {
        cString(buffer.map { UInt8(bitPattern: $0) })
    }
}
