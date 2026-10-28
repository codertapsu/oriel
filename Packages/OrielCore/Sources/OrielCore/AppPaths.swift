import Foundation

/// Where Oriel keeps its files. Everything lives under ~/Library/Application Support/Oriel.
public enum AppPaths {
    public static var applicationSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "Oriel", directoryHint: .isDirectory)
    }

    /// The CLI's Unix domain socket (PLAN §7.1.8).
    public static var ipcSocket: URL {
        applicationSupport.appending(path: "ipc.sock")
    }

    /// Dropped by `make install`, a DMG post-install step or MDM; imported and deleted on launch (PLAN §7.7.5).
    public static var bootstrapFile: URL {
        applicationSupport.appending(path: "bootstrap.json")
    }

    public static var captureHistory: URL {
        applicationSupport.appending(path: "History", directoryHint: .isDirectory)
    }

    public static var translationHistory: URL {
        applicationSupport.appending(path: "TranslationHistory", directoryHint: .isDirectory)
    }

    public static var recordings: URL {
        applicationSupport.appending(path: "Recordings", directoryHint: .isDirectory)
    }

    /// Creates `url` (and its parents) if needed and returns it.
    @discardableResult
    public static func ensureDirectory(_ url: URL) throws -> URL {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
