import os

/// One `os.Logger` per module. User content (titles, OCR text, translations) is logged `privacy: .private`.
public enum Log {
    public static let subsystem = "com.codertapsu.oriel"

    public static func logger(_ category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}
