/// The merge rule of settings sync (PLAN §7.16): per setting, the newest change on any Mac wins. Each setting is
/// independent, so there is nothing to reconcile beyond comparing dates.
public nonisolated enum SettingsMerge {
    /// The settings to change on this Mac: for every synced setting, the newest entry in the other Macs' snapshots,
    /// when it is newer than this Mac's and holds a different value. A setting this Mac never changed counts as
    /// changed at `Date.distantPast`, so a Mac that turns sync on adopts what the others already have.
    public static func changes(local: SettingsSnapshot, others: [SettingsSnapshot]) -> [String: SettingsSnapshot.Entry] {
        var newest: [String: SettingsSnapshot.Entry] = [:]
        for snapshot in others where snapshot.device != local.device {
            for (name, entry) in snapshot.entries where SettingsSyncPolicy.syncs(name) {
                if let current = newest[name], current.modified >= entry.modified {
                    continue
                }
                newest[name] = entry
            }
        }
        return newest.filter { name, remote in
            guard let mine = local.entries[name] else { return remote.value != nil }
            return remote.modified > mine.modified && remote.value != mine.value
        }
    }
}
