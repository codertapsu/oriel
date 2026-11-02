import OrielCore
@testable import OrielTranslation
import Testing

/// Apple Translation and Apple Intelligence are free; the other providers are Oriel Pro, and a translation through one
/// while Pro is locked fails with a message that says so (PLAN §19).
@MainActor
struct TranslationProTests {
    @Test func applesProvidersAreTheFreeOnes() {
        #expect(ProviderKind.allCases.filter { !$0.needsPro } == [.apple, .foundationModels])
    }

    @Test func aProProviderIsBlockedWhileProIsLocked() {
        let locked = ProAccess(isUnlocked: false)
        let deepL = ProviderConfig(id: "deepl", kind: .deepl)
        #expect(TranslationCoordinator.proBlock(deepL, access: locked) == .needsPro("DeepL"))
        #expect(TranslationCoordinator.proBlock(ProviderConfig(id: "apple", kind: .apple), access: locked) == nil)
        #expect(TranslationCoordinator.proBlock(deepL, access: ProAccess(isUnlocked: true)) == nil)
    }
}
