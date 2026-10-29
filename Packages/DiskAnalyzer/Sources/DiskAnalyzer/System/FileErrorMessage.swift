import Darwin
import Foundation

/// What went wrong with a file, in a sentence, from an `errno` or a Foundation error.
nonisolated enum FileErrorMessage {
    static func message(for code: Int32) -> String {
        switch code {
        case ENOSPC: "There is not enough free space there."
        case EACCES, EPERM: "Oriel is not allowed to change it. Without Full Disk Access some folders are off limits."
        case EROFS: "The volume is read-only."
        case ENOENT: "It is no longer there."
        case EEXIST: "Something with that name is already there."
        case ECANCELED: "Stopped."
        case EBUSY: "It is in use."
        case ENAMETOOLONG: "Its name is too long for the destination."
        case EXDEV: "It is on another volume."
        // What reading a file that is only in the cloud gives when downloading is turned off, as Oriel's file threads do.
        case EDEADLK: "It is only in the cloud. Download it in Finder first."
        default: String(cString: strerror(code)) + "."
        }
    }

    static func message(for error: any Error) -> String {
        let error = error as NSError
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError, underlying.domain == NSPOSIXErrorDomain {
            return message(for: Int32(underlying.code))
        }
        if error.domain == NSPOSIXErrorDomain {
            return message(for: Int32(error.code))
        }
        return error.localizedDescription
    }
}
