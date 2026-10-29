import OrielCore

/// The Screen Ruler's settings, all named `screenRuler.*` (Settings → Screen Ruler).
nonisolated enum RulerSettings {
    static let prefix = "screenRuler."

    /// The mode the ruler opens in.
    static let defaultMode = SettingKey("screenRuler.defaultMode", default: RulerMode.dimensions)
    /// The unit it opens with; U switches it for the session.
    static let unit = SettingKey("screenRuler.unit", default: RulerUnit.points)
    /// The color of guides, as `#RRGGBB`.
    static let guideColor = SettingKey("screenRuler.guideColor", default: "#FF2D55")
    /// How different two neighbouring pixels must be to make an edge, in percent of a channel's range; `[` and `]`
    /// change it during a session, and that is kept.
    static let tolerance = SettingKey("screenRuler.tolerance", default: 5)

    static let toleranceRange = 0 ... 50

    /// A percentage as a difference of 0…255 in one channel.
    static func channelTolerance(percent: Int) -> Int {
        Int((Double(min(max(percent, 0), 100)) * 2.55).rounded())
    }
}
