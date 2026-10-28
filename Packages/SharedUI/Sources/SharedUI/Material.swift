import AppKit

/// The one place that decides how floating chrome looks (PLAN §7.1.10, §10.2).
public enum Material {
    /// A glass (or, under the accessibility options, opaque) background for a panel's content.
    public static func make(cornerRadius: CGFloat = 16) -> GlassBackgroundView {
        GlassBackgroundView(cornerRadius: cornerRadius)
    }
}
