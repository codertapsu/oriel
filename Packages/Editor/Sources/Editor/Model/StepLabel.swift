/// How a step marker writes its number: 1, 2, 3; A, B, C; a, b, c; or I, II, III.
nonisolated enum StepLabel: String, Codable, Sendable, CaseIterable, Identifiable {
    case numbers
    case uppercase
    case lowercase
    case roman

    var id: String {
        rawValue
    }

    /// The picker's title, which shows the first three labels.
    var title: String {
        (1 ... 3).map(text(for:)).joined(separator: " ")
    }

    var accessibilityName: String {
        switch self {
        case .numbers: "Numbers"
        case .uppercase: "Capital letters"
        case .lowercase: "Lowercase letters"
        case .roman: "Roman numerals"
        }
    }

    /// The label of step `number`. Letters go on after Z as spreadsheet columns do (Z, AA, AB…); numbers that have
    /// no letter or Roman form (zero, negatives, 4000 and up) are written as digits.
    func text(for number: Int) -> String {
        switch self {
        case .numbers: String(number)
        case .uppercase: Self.letters(number) ?? String(number)
        case .lowercase: Self.letters(number)?.lowercased() ?? String(number)
        case .roman: Self.roman(number) ?? String(number)
        }
    }

    /// Bijective base 26: 1 → A, 26 → Z, 27 → AA.
    static func letters(_ number: Int) -> String? {
        guard number > 0 else { return nil }
        var value = number
        var scalars: [Character] = []
        while value > 0 {
            let remainder = (value - 1) % 26
            scalars.append(Character(UnicodeScalar(UInt8(65 + remainder))))
            value = (value - 1) / 26
        }
        return String(scalars.reversed())
    }

    static func roman(_ number: Int) -> String? {
        guard (1 ... 3999).contains(number) else { return nil }
        let values: [(Int, String)] = [
            (1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"), (90, "XC"),
            (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I"),
        ]
        var remaining = number
        var result = ""
        for (value, numeral) in values {
            while remaining >= value {
                result += numeral
                remaining -= value
            }
        }
        return result
    }
}
