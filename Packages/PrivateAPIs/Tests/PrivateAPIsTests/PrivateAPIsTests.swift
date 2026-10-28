import ApplicationServices
import Foundation
import PrivateAPIs
import Testing

struct PrivateAPIsTests {
    @Test func everySymbolMissingDisablesEverythingWithoutCrashing() {
        let apis = PrivateAPIs(resolver: .none)
        #expect(apis.presence.values.allSatisfy { !$0 })
        #expect(apis.presence.count == PrivateSymbol.allCases.count)
        #expect(!apis.canMapElementsToWindows && !apis.canReachOtherSpaces && !apis.canReadSpaces)
        #expect(!apis.canFocusWindows && !apis.canControlSymbolicHotKeys)
        #expect(apis.activeSpaceID() == nil)
        #expect(apis.managedDisplaySpaces() == nil)
        #expect(apis.spaceIDs(forWindow: 1) == nil)
        #expect(!apis.bringToFront(pid: getpid(), windowID: 1))
        #expect(apis.symbolicHotKeys().isEmpty)
        #expect(!apis.setSymbolicHotKey(1, enabled: true))
        #expect(apis.windowID(of: AXUIElementCreateApplication(getpid())) == nil)
    }

    @Test(arguments: PrivateSymbol.allCases)
    func eachSymbolCanBeMissingOnItsOwn(_ missing: PrivateSymbol) {
        let apis = PrivateAPIs(resolver: SymbolResolver { name in
            name == missing.rawValue ? nil : SymbolResolver.system.lookup(name)
        })
        #expect(apis.presence[missing] == false)
        _ = apis.managedDisplaySpaces()
        _ = apis.symbolicHotKeys(limit: 8)
    }

    @Test func remoteTokensHaveTheDocumentedLayout() {
        let token = PrivateAPIs.remoteToken(pid: 0x0102_0304, elementID: 0x0A0B)
        #expect(token.count == 20)
        #expect(Array(token[0 ..< 4]) == [0x04, 0x03, 0x02, 0x01])
        #expect(Array(token[4 ..< 8]) == [0, 0, 0, 0])
        // The four-character constant 'coco' (0x636F636F), stored little-endian like the other fields.
        #expect(Array(token[8 ..< 12]) == [0x6F, 0x63, 0x6F, 0x63])
        #expect(Array(token[12 ..< 20]) == [0x0B, 0x0A, 0, 0, 0, 0, 0, 0])
    }

    @Test func displaySpacesParseSkyLightsShapeAndIgnoreJunk() {
        let parsed = DisplaySpaces.parseForTesting([
            ["Display Identifier": "Main", "Current Space": ["id64": 5], "Spaces": [["id64": 5, "type": 0], ["id64": 9, "type": 4]]],
            "junk",
        ])
        #expect(parsed == [DisplaySpaces(displayIdentifier: "Main", currentSpaceID: 5, spaceIDs: [5, 9], fullScreenSpaceIDs: [9])])
        #expect(parsed.first?.index(of: 9) == 2)
    }

    /// The symbols the switcher relies on exist on the macOS this runs on (the plan's per-VM presence check).
    @Test func theSystemResolvesTheSwitchersSymbols() {
        let apis = PrivateAPIs.shared
        for symbol in PrivateSymbol.allCases {
            #expect(apis.presence[symbol] == true, "\(symbol.rawValue) is missing on this macOS")
        }
        #expect(apis.activeSpaceID() != nil)
    }
}
