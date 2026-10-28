import Foundation

/// Writes a file via a temp file + rename, so a crash never leaves it half written.
public enum AtomicFile {
    public static func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    /// `~/Library/Application Support/AntenimYok/<fileName>` (inside the container when sandboxed).
    public static func defaultURL(fileName: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("AntenimYok", isDirectory: true).appendingPathComponent(fileName)
    }
}
