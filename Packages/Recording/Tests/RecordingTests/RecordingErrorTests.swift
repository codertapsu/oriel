import AVFoundation
import Foundation
@testable import Recording
import ScreenCaptureKit
import Testing

struct RecordingErrorTests {
    @Test func recognizesAFullDisk() {
        #expect(RecordingError.isOutOfSpace(NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))))
        #expect(RecordingError.isOutOfSpace(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)))
        #expect(RecordingError.isOutOfSpace(NSError(domain: AVFoundationErrorDomain, code: AVError.Code.diskFull.rawValue)))
        let underlying = NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))
        #expect(RecordingError.isOutOfSpace(NSError(domain: "wrapper", code: 1, userInfo: [NSUnderlyingErrorKey: underlying])))
        #expect(!RecordingError.isOutOfSpace(NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))))
        #expect(RecordingError.from(underlying) == .insufficientStorage)
    }

    @Test func mapsScreenCaptureKitsDiskFullErrorOnMacOS27() {
        guard #available(macOS 27, *) else { return }
        let error = NSError(domain: SCStreamErrorDomain, code: SCStreamError.Code.insufficientStorage.rawValue)
        #expect(RecordingError.from(error) == .insufficientStorage)
    }

    @Test func aStopFromTheSystemMenuIsNotAFailure() {
        #expect(RecordingError.isUserStop(NSError(domain: SCStreamErrorDomain, code: SCStreamError.Code.userStopped.rawValue)))
        #expect(!RecordingError.isUserStop(NSError(domain: SCStreamErrorDomain, code: SCStreamError.Code.systemStoppedStream.rawValue)))
        #expect(!RecordingError.isUserStop(NSError(domain: NSCocoaErrorDomain, code: SCStreamError.Code.userStopped.rawValue)))
    }

    @Test func keepsRecordingErrorsAndWrapsTheRest() {
        #expect(RecordingError.from(RecordingError.windowNotFound) == .windowNotFound)
        let other = NSError(domain: "test", code: 7, userInfo: [NSLocalizedDescriptionKey: "Broken"])
        #expect(RecordingError.from(other) == .streamFailed("Broken"))
    }

    @Test(arguments: [
        RecordingError.alreadyRecording, .displayNotFound, .windowNotFound, .emptyArea, .insufficientStorage,
        .nothingRecorded, .streamFailed("x"), .exportFailed("y"),
    ])
    func everyErrorExplainsItself(error: RecordingError) {
        #expect(!(error.errorDescription ?? "").isEmpty)
    }
}
