import AppKit

/// The accessibility display options that change how Oriel draws (PLAN §7.1.9, §10.2), read live.
public struct AccessibilityDisplay: Equatable, Sendable {
    public var reduceTransparency: Bool
    public var increaseContrast: Bool
    public var reduceMotion: Bool

    public init(reduceTransparency: Bool, increaseContrast: Bool, reduceMotion: Bool) {
        self.reduceTransparency = reduceTransparency
        self.increaseContrast = increaseContrast
        self.reduceMotion = reduceMotion
    }

    public static var current: AccessibilityDisplay {
        let workspace = NSWorkspace.shared
        return AccessibilityDisplay(
            reduceTransparency: workspace.accessibilityDisplayShouldReduceTransparency,
            increaseContrast: workspace.accessibilityDisplayShouldIncreaseContrast,
            reduceMotion: workspace.accessibilityDisplayShouldReduceMotion
        )
    }

    /// Glass is drawn only when neither option asks for a solid background.
    public var allowsGlass: Bool {
        !reduceTransparency && !increaseContrast
    }

    /// Calls `handler` whenever the options change. Keep the token; dropping it stops the observation.
    public static func observe(_ handler: @escaping @MainActor (AccessibilityDisplay) -> Void) -> NSObjectProtocol {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { handler(.current) }
        }
    }
}
