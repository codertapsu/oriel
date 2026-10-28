import Foundation
@testable import OrielTranslation
import Testing

struct LanguageCatalogTests {
    @Test(arguments: [
        ("zh-Hant-TW", "zh-Hant"), ("zh-TW", "zh-Hant"), ("zh-CN", "zh-Hans"), ("zh", "zh-Hans"), ("en-GB", "en-GB"), ("en", "en"),
        ("pt-BR", "pt-BR"), ("ja-JP", "ja"), ("fr-CA", "fr"),
    ])
    func normalizesCodes(_ identifier: String, _ code: String) {
        #expect(LanguageCatalog.code(for: Locale.Language(identifier: identifier)) == code)
    }

    @Test func comparesLanguagesLikeATranslatorWould() {
        let language = Locale.Language.init(identifier:)
        #expect(LanguageCatalog.isSameLanguage(language("en-US"), language("en-GB")))
        #expect(!LanguageCatalog.isSameLanguage(language("zh-Hans"), language("zh-Hant")))
        #expect(!LanguageCatalog.isSameLanguage(language("ja"), language("ko")))
        #expect(LanguageCatalog.isRightToLeft(language("ar")) && LanguageCatalog.isRightToLeft(language("he")))
        #expect(!LanguageCatalog.isRightToLeft(language("ja")))
        #expect(LanguageCatalog.englishName(of: language("ja")) == "Japanese")
        #expect(LanguageCatalog.language(for: "") == LanguageCatalog.systemLanguage)
    }
}
