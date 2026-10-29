import Foundation

/// The internal battery, from `IOPSCopyPowerSourcesInfo`, on Macs that have one.
nonisolated struct BatteryReading: Sendable, Equatable, Codable {
    /// 0–100.
    let percent: Int
    let isCharging: Bool
    let isCharged: Bool
    let onBattery: Bool
    /// To empty on battery, or to full while charging; nil while macOS is still estimating.
    let minutesRemaining: Int?

    init(percent: Int, isCharging: Bool, isCharged: Bool, onBattery: Bool, minutesRemaining: Int?) {
        self.percent = percent
        self.isCharging = isCharging
        self.isCharged = isCharged
        self.onBattery = onBattery
        self.minutesRemaining = minutesRemaining
    }

    /// One power source's description dictionary; nil for anything but a present internal battery (a UPS, say).
    init?(description: [String: Any]) {
        guard description["Type"] as? String == "InternalBattery", description["Is Present"] as? Bool ?? true,
              let current = (description["Current Capacity"] as? NSNumber)?.intValue
        else { return nil }
        let maximum = max(1, (description["Max Capacity"] as? NSNumber)?.intValue ?? 100)
        let charging = description["Is Charging"] as? Bool ?? false
        let onBattery = description["Power Source State"] as? String == "Battery Power"
        let minutes = (description[charging ? "Time to Full Charge" : "Time to Empty"] as? NSNumber)?.intValue
        self.init(
            percent: min(100, max(0, current * 100 / maximum)),
            isCharging: charging,
            isCharged: description["Is Charged"] as? Bool ?? false,
            onBattery: onBattery,
            // -1 while estimating; 0 on power, where there is nothing to count down.
            minutesRemaining: minutes.flatMap { $0 > 0 && (onBattery || charging) ? $0 : nil }
        )
    }

    /// "Charged", "Charging", "On battery" or "Not charging".
    var state: String {
        if isCharged, !onBattery {
            return "Charged"
        }
        return isCharging ? "Charging" : onBattery ? "On battery" : "Not charging"
    }

    /// "84 %, charging", "Charged", "62 %, on battery".
    var stateTitle: String {
        if isCharged, !onBattery {
            return "Charged"
        }
        return "\(percent) %, \(state.lowercased())"
    }
}
