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

/// A missing item reads as nil rather than throwing, which is how Clipboard History tells "no key yet" from "keychain
/// locked" and never replaces a key it merely could not read.
@Test(.requiresTCC)
func keychainDataRoundTripAndMissingItems() throws {
    let keychain = KeychainStore(prefix: "com.codertapsu.oriel.tests")
    let service = "data.\(UUID().uuidString)"
    defer { try? keychain.remove(service: service) }
    #expect(try keychain.data(service: service, account: "key") == nil)
    let bytes = Data((0 ..< 32).map { UInt8($0) })
    try keychain.setData(bytes, service: service, account: "key")
    #expect(try keychain.data(service: service, account: "key") == bytes)
    try keychain.setData(nil, service: service, account: "key")
    #expect(try keychain.data(service: service, account: "key") == nil)
}
