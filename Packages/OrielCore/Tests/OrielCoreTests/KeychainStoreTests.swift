import Foundation
import OrielCore
import OrielTestSupport
import Testing

/// Touches the login keychain, so it runs with the TCC tests on the dev Mac only.
@Test(.requiresTCC)
func keychainRoundTrip() throws {
    let keychain = KeychainStore(prefix: "com.codertapsu.oriel.tests")
    let service = "roundtrip.\(UUID().uuidString)"
    defer { try? keychain.remove(service: service) }
    try keychain.setString("s3cr3t", service: service)
    #expect(keychain.string(service: service) == "s3cr3t")
    try keychain.setString(nil, service: service)
    #expect(keychain.string(service: service) == nil)
}
