@testable import DiskAnalyzer
import Testing

/// Capacity, purgeable space and how a volume scan adds up.
struct VolumeUsageTests {
    @Test func purgeableIsWhatImportantUseCouldHaveBeyondWhatIsFree() {
        let usage = VolumeUsage(
            total: 494_000_000_000, available: 90_000_000_000,
            availableForImportantUsage: 120_000_000_000, availableForOpportunisticUsage: 80_000_000_000
        )
        #expect(usage.used == 404_000_000_000)
        #expect(usage.purgeable == 30_000_000_000)
        #expect(usage.usedWithoutPurgeable == 374_000_000_000)
        #expect(usage.availableIncludingPurgeable == 120_000_000_000)
        #expect(!usage.isNearlyFull)
    }

    @Test func missingOrOddFiguresNeverGoNegative() {
        let unknown = VolumeUsage(total: 100, available: 40, availableForImportantUsage: nil, availableForOpportunisticUsage: nil)
        #expect(unknown.purgeable == 0)
        let lower = VolumeUsage(total: 100, available: 40, availableForImportantUsage: 30, availableForOpportunisticUsage: nil)
        #expect(lower.purgeable == 0)
        let beyond = VolumeUsage(total: 100, available: 40, availableForImportantUsage: 500, availableForOpportunisticUsage: nil)
        #expect(beyond.purgeable == 60)
        #expect(beyond.availableIncludingPurgeable == 100)
        let negative = VolumeUsage(total: 100, available: -5, availableForImportantUsage: nil, availableForOpportunisticUsage: nil)
        #expect(negative.used == 100)
        let empty = VolumeUsage(total: 0, available: 0, availableForImportantUsage: nil, availableForOpportunisticUsage: nil)
        #expect(empty.fraction(10) == 0)
    }

    @Test func aNearlyFullVolumeIsFlagged() {
        let full = VolumeUsage(
            total: 500_000_000_000,
            available: 4_000_000_000,
            availableForImportantUsage: 6_000_000_000,
            availableForOpportunisticUsage: nil
        )
        #expect(full.isNearlyFull)
        #expect(full.fraction(full.used) > 0.98)
    }

    @Test func theStartupVolumeScanAddsTheSystemAndWhatNoFileAccountsFor() {
        let blocks = VolumeAccounting.blocks(volumeUsed: 404_000_000_000, scanned: 360_000_000_000, system: 24_000_000_000)
        #expect(blocks.system == 24_000_000_000)
        #expect(blocks.unaccounted == 20_000_000_000)
    }

    @Test func smallOrNegativeRemaindersAreLeftOut() {
        #expect(VolumeAccounting.blocks(volumeUsed: 100_000_000_000, scanned: 99_950_000_000, system: 0).unaccounted == 0)
        // Clones counted at full size can make a scan larger than what is used.
        #expect(VolumeAccounting.blocks(volumeUsed: 100_000_000_000, scanned: 120_000_000_000, system: 0).unaccounted == 0)
    }

    @Test func volumesAreClassified() {
        #expect(VolumeKind.of(isRoot: true, isLocal: true, isInternal: true) == .startup)
        #expect(VolumeKind.of(isRoot: false, isLocal: false, isInternal: nil) == .network)
        #expect(VolumeKind.of(isRoot: false, isLocal: true, isInternal: true) == .internalDisk)
        #expect(VolumeKind.of(isRoot: false, isLocal: true, isInternal: false) == .external)
        #expect(VolumeKind.of(isRoot: false, isLocal: true, isInternal: nil) == .external)
    }

    @Test func onlyRemovableVolumesOfferEject() {
        let usage = VolumeUsage(total: 1, available: 1, availableForImportantUsage: nil, availableForOpportunisticUsage: nil)
        let startup = VolumeInfo(
            path: "/",
            name: "Macintosh HD",
            format: "APFS",
            usage: usage,
            kind: .startup,
            isReadOnly: true,
            isEjectable: false
        )
        let usb = VolumeInfo(path: "/Volumes/USB", name: "USB", format: "ExFAT", usage: usage, kind: .external, isEjectable: true)
        let share = VolumeInfo(path: "/Volumes/Share", name: "Share", format: "SMB", usage: usage, kind: .network)
        #expect(!startup.canEject)
        #expect(usb.canEject)
        #expect(share.canEject)
        #expect(startup.canHaveLocalSnapshots)
        #expect(!usb.canHaveLocalSnapshots)
    }

    @Test func scanningTheStartupVolumeReadsItsDataVolume() {
        let usage = VolumeUsage(total: 1, available: 1, availableForImportantUsage: nil, availableForOpportunisticUsage: nil)
        let volumes = [
            VolumeInfo(path: "/", name: "Macintosh HD", format: "APFS", usage: usage, kind: .startup),
            VolumeInfo(path: "/Volumes/USB", name: "USB", format: "ExFAT", usage: usage, kind: .external),
        ]
        let startup = ScanTarget.resolve(path: "/", volumes: volumes, dataVolumeExists: true, firmlinks: .empty)
        #expect(startup.scanPath == "/System/Volumes/Data")
        #expect(startup.displayName == "Macintosh HD")
        #expect(startup.isStartupVolume)
        let usb = ScanTarget.resolve(path: "/Volumes/USB/", volumes: volumes, dataVolumeExists: true, firmlinks: .empty)
        #expect(usb.scanPath == "/Volumes/USB")
        #expect(usb.volume?.name == "USB")
        let folder = ScanTarget.resolve(path: "/Users/me/Movies", volumes: volumes, dataVolumeExists: true, firmlinks: .empty)
        #expect(folder.scanPath == "/Users/me/Movies")
        #expect(folder.displayName == "Movies")
        #expect(folder.volume == nil)
    }
}
