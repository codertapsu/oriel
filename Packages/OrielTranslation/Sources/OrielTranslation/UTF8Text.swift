/// Decodes UTF-8 from servers and models leniently: an invalid or cut-off sequence becomes U+FFFD instead of
/// losing the whole text.
enum UTF8Text {
    static func decode(_ bytes: some Sequence<UInt8>) -> String {
        var scalars = String.UnicodeScalarView()
        var iterator = bytes.makeIterator()
        var decoder = UTF8()
        while true {
            switch decoder.decode(&iterator) {
            case let .scalarValue(scalar):
                scalars.append(scalar)
            case .emptyInput:
                return String(scalars)
            case .error:
                scalars.append("\u{FFFD}")
            }
        }
    }
}
