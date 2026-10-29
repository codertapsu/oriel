import Foundation
import OrielCore

/// What the camera bubble shows behind the person (PLAN §17): the picture as the camera sends it, the background
/// blurred, or the background replaced by a colour. Oriel's own effect needs Vision person segmentation, which
/// is fast enough only on Apple silicon, natively. Pure.
nonisolated enum CameraBackground: Equatable, Sendable {
    case unchanged
    case blurred
    /// sRGB components from 0 to 1.
    case replaced(red: Double, green: Double, blue: Double)

    /// Whether this Mac can run the effect: Apple silicon, not under Rosetta.
    static var gate: FeatureGate {
        gate(isAppleSilicon: HardwareInfo.isAppleSiliconHardware, isTranslated: HardwareInfo.isTranslated)
    }

    static func gate(isAppleSilicon: Bool, isTranslated: Bool) -> FeatureGate {
        FeatureGate.all(
            (isAppleSilicon, "Blurring the camera background needs a Mac with Apple silicon."),
            (!isTranslated, "Blurring the camera background does not run under Rosetta.")
        )
    }

    /// The effect the settings ask for, or `.unchanged` when the gate is closed.
    static func resolve(blurs: Bool, style: CameraBackgroundStyle, colorHex: String, gate: FeatureGate) -> CameraBackground {
        guard blurs, gate.isOpen else { return .unchanged }
        switch style {
        case .blur:
            return .blurred
        case .color:
            let rgb = components(fromHex: colorHex) ?? components(fromHex: CameraBackgroundStyle.defaultColorHex) ?? (0, 0, 0)
            return .replaced(red: rgb.red, green: rgb.green, blue: rgb.blue)
        }
    }

    /// `#RRGGBB` (the `#` optional) as components from 0 to 1, or nil when it is not one.
    static func components(fromHex hex: String) -> (red: Double, green: Double, blue: Double)? {
        var digits = hex.trimmingCharacters(in: .whitespaces)
        if digits.hasPrefix("#") {
            digits.removeFirst()
        }
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        return (Double(value >> 16 & 0xFF) / 255, Double(value >> 8 & 0xFF) / 255, Double(value & 0xFF) / 255)
    }

    /// Components from 0 to 1 as `#RRGGBB`.
    static func hex(red: Double, green: Double, blue: Double) -> String {
        let channels = [red, green, blue].map { Int((min(max($0.isFinite ? $0 : 0, 0), 1) * 255).rounded()) }
        return "#" + channels.map { String(format: "%02X", $0) }.joined()
    }
}
