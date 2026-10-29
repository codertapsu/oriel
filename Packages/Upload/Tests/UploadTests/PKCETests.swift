import Foundation
import Testing
@testable import Upload

struct PKCETests {
    /// RFC 7636 appendix B.
    @Test func theS256ChallengeMatchesTheRFCExample() {
        let pkce = PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        #expect(pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        #expect(PKCE.method == "S256")
    }

    @Test func verifiersAre43UnreservedCharactersAndNeverRepeat() {
        let first = PKCE.generate()
        let second = PKCE.generate()
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        #expect(first.verifier.count == 43)
        #expect(first.verifier.unicodeScalars.allSatisfy(unreserved.contains))
        #expect(first.verifier != second.verifier)
        #expect(first.challenge.count == 43)
    }

    @Test func base64URLUsesTheURLSafeAlphabetWithoutPadding() {
        #expect(PKCE.base64URL(Data([0xFB, 0xFF, 0xFE])) == "-__-")
        #expect(PKCE.base64URL(Data([0x61])) == "YQ")
    }
}
