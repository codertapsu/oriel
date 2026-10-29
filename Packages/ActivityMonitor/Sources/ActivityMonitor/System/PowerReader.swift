import Foundation
import IOKit.ps
import IOKit.pwr_mgt

/// The battery and the power assertions that keep the Mac awake, from IOKit's power APIs.
nonisolated enum PowerReader {
    /// The internal battery, on Macs that have one.
    static func battery() -> BatteryReading? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        let descriptions = sources.compactMap { IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any] }
        return descriptions.lazy.compactMap(BatteryReading.init(description:)).first
    }

    /// The assertions that stop the Mac or its display from sleeping, by pid.
    static func sleepAssertions() -> [Int32: [String]] {
        var assertions: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&assertions) == kIOReturnSuccess,
              let byProcess = assertions?.takeRetainedValue() as? [NSNumber: [[String: Any]]]
        else { return [:] }
        var result: [Int32: [String]] = [:]
        for (pid, list) in byProcess {
            let kinds = Set(list.compactMap { $0["AssertType"] as? String }.filter(preventsSleep))
            if !kinds.isEmpty {
                result[pid.int32Value] = kinds.sorted()
            }
        }
        return result
    }

    /// "PreventUserIdleSystemSleep", "PreventUserIdleDisplaySleep", "NoIdleSleepAssertion" and the like; not
    /// "UserIsActive", which only says someone touched the keyboard.
    static func preventsSleep(_ type: String) -> Bool {
        type.contains("Sleep")
    }
}
