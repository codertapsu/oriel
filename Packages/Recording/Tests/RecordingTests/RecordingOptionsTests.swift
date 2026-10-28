import Foundation
import OrielCore
@testable import Recording
import Testing

@MainActor
struct RecordingOptionsTests {
    private typealias Keys = RecordingSettingKeys

    private func withSettings(_ body: (SettingsStore) throws -> Void) throws {
        let suite = "oriel-recording-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(SettingsStore(defaults: defaults))
    }

    @Test func defaultsToStandardWithSystemAudioAndThePointer() throws {
        try withSettings { settings in
            let options = RecordingOptions(settings: settings)
            #expect(options.preset == .standard)
            #expect(options.frameRate == 30)
            #expect(options.codec == .h264)
            #expect(options.showsCursor)
            #expect(options.systemAudio)
            #expect(!options.microphone)
            #expect(options.microphoneDeviceID == nil)
            #expect(!options.cameraBubble)
            #expect(!options.clickRings)
            #expect(!options.keystrokes)
            #expect(options.outputFolder == AppPaths.recordings)
            #expect(options.gif == GIFExportOptions(frameRate: 10, maxWidth: 800))
        }
    }

    @Test func readsEverySetting() throws {
        try withSettings { settings in
            settings[Keys.preset] = .high
            settings[Keys.frameRate] = 30
            settings[Keys.codec] = .h264
            settings[Keys.showsCursor] = false
            settings[Keys.systemAudio] = false
            settings[Keys.microphone] = true
            settings[Keys.microphoneDeviceID] = "mic-1"
            settings[Keys.cameraBubble] = true
            settings[Keys.clickRings] = true
            settings[Keys.keystrokes] = true
            settings[Keys.outputFolder] = "/tmp/Oriel Movies"
            settings[Keys.gifMaxWidth] = 640
            settings[Keys.gifFrameRate] = 15

            let options = RecordingOptions(settings: settings)
            #expect(options.preset == .high)
            #expect(options.frameRate == 30)
            #expect(options.codec == .h264)
            #expect(!options.showsCursor)
            #expect(!options.systemAudio)
            #expect(options.microphone)
            #expect(options.microphoneDeviceID == "mic-1")
            #expect(options.cameraBubble)
            #expect(options.clickRings)
            #expect(options.keystrokes)
            #expect(options.outputFolder.path == "/tmp/Oriel Movies")
            #expect(options.gif == GIFExportOptions(frameRate: 15, maxWidth: 640))
        }
    }

    @Test func thePresetSuppliesTheRateAndCodecUntilSettingsOverrideThem() throws {
        try withSettings { settings in
            settings[Keys.preset] = .high
            #expect(RecordingOptions(settings: settings).frameRate == 60)
            #expect(RecordingOptions(settings: settings).codec == .hevc)
            settings[Keys.frameRate] = 24
            settings.reset(Keys.codec)
            #expect(RecordingOptions(settings: settings).frameRate == 24)
            #expect(RecordingOptions(settings: settings).codec == .hevc)
        }
    }

    @Test func expandsTheHomeFolderAndFallsBackToTheDefault() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        let movies = RecordingOptions.folder(fromPath: "~/Movies").path(percentEncoded: false)
        #expect(movies.hasPrefix(home.hasSuffix("/") ? String(home.dropLast()) : home))
        #expect(movies.hasSuffix("Movies") || movies.hasSuffix("Movies/"))
        #expect(RecordingOptions.folder(fromPath: "  ") == AppPaths.recordings)
        #expect(RecordingOptions.folder(fromPath: "") == AppPaths.recordings)
    }

    @Test func everySettingNameSharesThePanePrefix() {
        let names = [
            Keys.preset.name, Keys.frameRate.name, Keys.codec.name, Keys.showsCursor.name, Keys.systemAudio.name,
            Keys.microphone.name, Keys.microphoneDeviceID.name, Keys.cameraBubble.name, Keys.clickRings.name,
            Keys.keystrokes.name, Keys.outputFolder.name, Keys.gifMaxWidth.name, Keys.gifFrameRate.name,
        ]
        #expect(names.allSatisfy { $0.hasPrefix(Keys.prefix) })
        #expect(Set(names).count == names.count)
    }
}
