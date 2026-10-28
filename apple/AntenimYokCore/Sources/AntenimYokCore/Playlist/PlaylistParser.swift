import Foundation

public enum PlaylistFormat: Sendable {
    case pls
    case m3u
}

/// Extracts stream URLs from .pls / .m3u playlist files.
public enum PlaylistParser {
    /// Detects a playlist by file extension. HLS (.m3u8) is not a playlist here; the player handles it.
    public static func detectFormat(of url: URL) -> PlaylistFormat? {
        let path = url.path.lowercased()
        if path.hasSuffix(".pls") { return .pls }
        if path.hasSuffix(".m3u") { return .m3u }
        return nil
    }

    /// Entries in file order; relative entries resolve against `baseURL`. Only http(s) URLs are kept.
    public static func parse(_ content: String, format: PlaylistFormat, baseURL: URL) -> [URL] {
        var urls: [URL] = []
        for rawLine in content.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            let candidate: String? = switch format {
            case .pls: plsValue(of: line)
            case .m3u: line.hasPrefix("#") ? nil : line
            }

            if let candidate,
               let url = URL(string: candidate, relativeTo: baseURL)?.absoluteURL,
               let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                urls.append(url)
            }
        }
        return urls
    }

    // "File1=http://host/stream"
    private static func plsValue(of line: String) -> String? {
        guard line.lowercased().hasPrefix("file"), let eq = line.firstIndex(of: "="), eq != line.startIndex else {
            return nil
        }
        return String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
    }
}
