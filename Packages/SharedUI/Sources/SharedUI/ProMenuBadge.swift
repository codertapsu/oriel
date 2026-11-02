import AppKit
import OrielCore

/// The "Pro" badge on a menu item that starts a Pro feature while Oriel Pro is locked (PLAN §19). Menus are built each
/// time they open, so the badge always matches the state.
public enum ProMenuBadge {
    public static func apply(_ feature: ProFeature?, to item: NSMenuItem, access: ProAccess = .shared) {
        item.badge = feature != nil && !access.isUnlocked ? NSMenuItemBadge(string: "Pro") : nil
    }
}
