import AVFoundation

/// A microphone settings can pick. Listing devices opens none of them and needs no permission.
nonisolated struct AudioInputDevice: Identifiable, Hashable, Sendable {
    /// `AVCaptureDevice.uniqueID`, which `SCStreamConfiguration.microphoneCaptureDeviceID` takes.
    let id: String
    let name: String

    /// The connected microphones, built-in and external, in the system's order.
    static func available() -> [AudioInputDevice] {
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone], mediaType: .audio, position: .unspecified)
        var seen = Set<String>()
        return discovery.devices.compactMap { device in
            seen.insert(device.uniqueID).inserted ? AudioInputDevice(id: device.uniqueID, name: device.localizedName) : nil
        }
    }
}
