import OrielCore
import Testing

struct FeatureGateTests {
    @Test func theFirstUnmetConditionCloses() {
        #expect(FeatureGate.all((true, "a"), (true, "b")) == .open)
        let gate = FeatureGate.all((true, "macOS 27"), (false, "needs Apple Intelligence"), (false, "disabled"))
        #expect(!gate.isOpen)
        #expect(gate.reason == "needs Apple Intelligence")
    }

    @Test func hardwareMatchesTheCompiledSlice() {
        #if arch(arm64)
            #expect(HardwareInfo.architecture == "arm64")
            #expect(HardwareInfo.isAppleSiliconHardware)
        #else
            #expect(HardwareInfo.architecture == "x86_64")
        #endif
    }
}
