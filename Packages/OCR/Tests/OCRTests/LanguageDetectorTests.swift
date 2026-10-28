import Foundation
import OCR
import Testing

struct LanguageDetectorTests {
    @Test(arguments: [
        ("The quick brown fox jumps over the lazy dog.", "en"),
        ("Le renard brun saute par-dessus le chien paresseux.", "fr"),
        ("Der schnelle braune Fuchs springt über den faulen Hund.", "de"),
        ("素早い茶色の狐がのろまな犬を飛び越える。", "ja"),
    ])
    func detectsTheLanguageOfAText(_ text: String, _ code: String) {
        #expect(LanguageDetector.languageCode(of: text) == code)
        #expect(LanguageDetector.dominantLanguage(of: [text])?.languageCode?.identifier == code)
    }

    @Test func picksTheLanguageMostTextIsWrittenIn() {
        let texts = [
            "Settings",
            "Choose how the application checks for updates and where it stores your documents.",
            "Bonjour",
        ]
        #expect(LanguageDetector.dominantLanguage(of: texts)?.languageCode?.identifier == "en")
    }

    @Test func returnsNilWithoutLetters() {
        #expect(LanguageDetector.languageCode(of: "") == nil)
        #expect(LanguageDetector.languageCode(of: "12:45 — 3.14 %") == nil)
        #expect(LanguageDetector.dominantLanguage(of: []) == nil)
    }
}
