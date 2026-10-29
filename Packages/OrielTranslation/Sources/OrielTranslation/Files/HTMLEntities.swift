/// Decodes HTML character references: numeric ones (`&#233;`, `&#xE9;`) and the named ones that occur in practice.
/// Unknown names stay as they are.
enum HTMLEntities {
    static func decode(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        result.reserveCapacity(text.count)
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            guard character == "&", let end = text[index...].prefix(12).firstIndex(of: ";") else {
                result.append(character)
                index = text.index(after: index)
                continue
            }
            let name = text[text.index(after: index) ..< end]
            if let decoded = value(of: name) {
                result += decoded
                index = text.index(after: end)
            } else {
                result.append(character)
                index = text.index(after: index)
            }
        }
        return result
    }

    private static func value(of name: Substring) -> String? {
        if name.hasPrefix("#") {
            let digits = name.dropFirst()
            let number = digits.first == "x" || digits.first == "X" ? UInt32(digits.dropFirst(), radix: 16) : UInt32(digits)
            guard let number, number != 0, let scalar = Unicode.Scalar(number) else { return nil }
            return String(Character(scalar))
        }
        return named[String(name)]
    }

    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}", "shy": "",
        "lrm": "\u{200E}", "rlm": "\u{200F}", "zwj": "\u{200D}", "zwnj": "\u{200C}",
        "copy": "©", "reg": "®", "trade": "™", "hellip": "…", "mdash": "—", "ndash": "–", "minus": "−",
        "lsquo": "‘", "rsquo": "’", "sbquo": "‚", "ldquo": "“", "rdquo": "”", "bdquo": "„", "laquo": "«", "raquo": "»",
        "lsaquo": "‹", "rsaquo": "›", "bull": "•", "middot": "·", "deg": "°", "plusmn": "±", "times": "×", "divide": "÷",
        "euro": "€", "pound": "£", "yen": "¥", "cent": "¢", "sect": "§", "para": "¶", "frac12": "½", "frac14": "¼",
        "frac34": "¾", "sup2": "²", "sup3": "³", "micro": "µ", "iexcl": "¡", "iquest": "¿", "larr": "←", "rarr": "→",
        "uarr": "↑", "darr": "↓", "harr": "↔", "dagger": "†", "Dagger": "‡", "prime": "′", "Prime": "″", "ensp": "\u{2002}",
        "emsp": "\u{2003}", "thinsp": "\u{2009}",
        "agrave": "à", "aacute": "á", "acirc": "â", "atilde": "ã", "auml": "ä", "aring": "å", "aelig": "æ", "ccedil": "ç",
        "egrave": "è", "eacute": "é", "ecirc": "ê", "euml": "ë", "igrave": "ì", "iacute": "í", "icirc": "î", "iuml": "ï",
        "ntilde": "ñ", "ograve": "ò", "oacute": "ó", "ocirc": "ô", "otilde": "õ", "ouml": "ö", "oslash": "ø", "ugrave": "ù",
        "uacute": "ú", "ucirc": "û", "uuml": "ü", "yacute": "ý", "yuml": "ÿ", "szlig": "ß", "eth": "ð", "thorn": "þ",
        "Agrave": "À", "Aacute": "Á", "Acirc": "Â", "Atilde": "Ã", "Auml": "Ä", "Aring": "Å", "AElig": "Æ", "Ccedil": "Ç",
        "Egrave": "È", "Eacute": "É", "Ecirc": "Ê", "Euml": "Ë", "Igrave": "Ì", "Iacute": "Í", "Icirc": "Î", "Iuml": "Ï",
        "Ntilde": "Ñ", "Ograve": "Ò", "Oacute": "Ó", "Ocirc": "Ô", "Otilde": "Õ", "Ouml": "Ö", "Oslash": "Ø", "Ugrave": "Ù",
        "Uacute": "Ú", "Ucirc": "Û", "Uuml": "Ü", "Yacute": "Ý", "oelig": "œ", "OElig": "Œ", "scaron": "š", "Scaron": "Š",
    ]
}
