import Foundation
import OrielCore
@testable import Recording
import Testing

struct CameraBackgroundTests {
    @Test func needsAppleSiliconNatively() {
        #expect(CameraBackground.gate(isAppleSilicon: true, isTranslated: false).isOpen)
        #expect(!CameraBackground.gate(isAppleSilicon: false, isTranslated: false).isOpen)
        #expect(!CameraBackground.gate(isAppleSilicon: true, isTranslated: true).isOpen)
    }

    @Test func resolvesTheSettings() {
        let open = FeatureGate.open
        #expect(CameraBackground.resolve(blurs: false, style: .blur, colorHex: "#000000", gate: open) == .unchanged)
        #expect(CameraBackground.resolve(blurs: true, style: .blur, colorHex: "#000000", gate: open) == .blurred)
        #expect(CameraBackground.resolve(blurs: true, style: .color, colorHex: "#FF8000", gate: open)
            == .replaced(red: 1, green: 128.0 / 255, blue: 0))
        #expect(CameraBackground.resolve(blurs: true, style: .blur, colorHex: "", gate: .closed("Intel")) == .unchanged)
        // A broken color falls back to the default grey.
        #expect(CameraBackground.resolve(blurs: true, style: .color, colorHex: "nope", gate: open) != .unchanged)
    }

    @Test func readsAndWritesHexColors() throws {
        let rgb = try #require(CameraBackground.components(fromHex: "2C2C2E"))
        #expect(abs(rgb.red - 44.0 / 255) < 1e-9)
        #expect(CameraBackground.hex(red: rgb.red, green: rgb.green, blue: rgb.blue) == "#2C2C2E")
        #expect(CameraBackground.components(fromHex: "#12345") == nil)
        #expect(CameraBackground.hex(red: 2, green: -1, blue: .nan) == "#FF0000")
    }

    @Test func governorSegmentsAtMostFifteenTimesASecond() {
        var governor = SegmentationGovernor()
        let times = stride(from: 0.0, to: 1.0, by: 1.0 / 30)
        let segmented = times.filter { governor.shouldSegment(at: $0) }
        #expect(segmented.count == 15)
    }

    @Test func governorStopsWhenSegmentationIsTooSlow() {
        var governor = SegmentationGovernor()
        governor.record(cost: 0.7)
        for _ in 0 ..< 10 {
            governor.record(cost: 0.012)
        }
        #expect(governor.isRunning)
        for _ in 0 ..< 20 {
            governor.record(cost: 0.08)
        }
        #expect(!governor.isRunning)
        #expect(governor.stopReason?.contains("ms a frame") == true)
        let segments = governor.shouldSegment(at: 100)
        #expect(!segments)
    }

    @Test func governorStopsWhenHotOrSavingPower() {
        var hot = SegmentationGovernor()
        hot.observe(thermalState: .serious, lowPowerMode: false)
        #expect(!hot.isRunning)
        var saving = SegmentationGovernor()
        saving.observe(thermalState: .nominal, lowPowerMode: true)
        #expect(saving.stopReason == "Low Power Mode is on")
        var fine = SegmentationGovernor()
        fine.observe(thermalState: .fair, lowPowerMode: false)
        #expect(fine.isRunning)
    }
}
