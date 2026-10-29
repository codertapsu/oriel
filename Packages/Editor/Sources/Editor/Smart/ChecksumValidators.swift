/// The checksums that tell a real card number or IBAN from a run of digits that only looks like one. Pure.
nonisolated enum ChecksumValidators {
    /// The Luhn check every payment card number passes.
    static func passesLuhn(_ digits: [Int]) -> Bool {
        guard !digits.isEmpty else { return false }
        var sum = 0
        for (position, digit) in digits.reversed().enumerated() {
            if position % 2 == 1 {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }
        return sum % 10 == 0
    }

    /// A card number: 13 to 19 digits that pass the Luhn check and are not all one digit.
    static func isCardNumber(_ text: String) -> Bool {
        let digits = text.compactMap(\.wholeNumberValue)
        guard (13 ... 19).contains(digits.count), Set(digits).count > 1 else { return false }
        return passesLuhn(digits)
    }

    /// An IBAN: a known country's length and the ISO 13616 mod-97 check. Spaces are ignored.
    static func isIBAN(_ text: String) -> Bool {
        let compact = text.uppercased().filter { !$0.isWhitespace }
        guard compact.count >= 15, compact.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return false }
        let country = String(compact.prefix(2))
        guard let length = ibanLengths[country], compact.count == length else { return false }
        // Move the first four characters to the end, read letters as 10…35, and the remainder by 97 must be 1.
        let rearranged = compact.dropFirst(4) + compact.prefix(4)
        var remainder = 0
        for character in rearranged {
            if let digit = character.wholeNumberValue {
                remainder = (remainder * 10 + digit) % 97
            } else if let ascii = character.asciiValue {
                remainder = (remainder * 100 + Int(ascii) - 55) % 97
            } else {
                return false
            }
        }
        return remainder == 1
    }

    /// The IBAN length of every country in the SWIFT registry.
    static let ibanLengths: [String: Int] = [
        "AD": 24, "AE": 23, "AL": 28, "AT": 20, "AZ": 28, "BA": 20, "BE": 16, "BG": 22, "BH": 22, "BI": 27, "BR": 29,
        "BY": 28, "CH": 21, "CR": 22, "CY": 28, "CZ": 24, "DE": 22, "DJ": 27, "DK": 18, "DO": 28, "EE": 20, "EG": 29,
        "ES": 24, "FI": 18, "FK": 18, "FO": 18, "FR": 27, "GB": 22, "GE": 22, "GI": 23, "GL": 18, "GR": 27, "GT": 28,
        "HN": 28, "HR": 21, "HU": 28, "IE": 22, "IL": 23, "IQ": 23, "IS": 26, "IT": 27, "JO": 30, "KW": 30, "KZ": 20,
        "LB": 28, "LC": 32, "LI": 21, "LT": 20, "LU": 20, "LV": 21, "LY": 25, "MC": 27, "MD": 24, "ME": 22, "MK": 19,
        "MN": 20, "MR": 27, "MT": 31, "MU": 30, "NI": 28, "NL": 18, "NO": 15, "OM": 23, "PK": 24, "PL": 28, "PS": 29,
        "PT": 25, "QA": 29, "RO": 24, "RS": 22, "RU": 33, "SA": 24, "SC": 31, "SD": 18, "SE": 24, "SI": 19, "SK": 24,
        "SM": 27, "SO": 23, "ST": 25, "SV": 28, "TL": 23, "TN": 24, "TR": 26, "UA": 29, "VA": 22, "VG": 24, "XK": 20,
        "YE": 30,
    ]
}
