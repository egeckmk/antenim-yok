import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var lastStationId: String?
    /// 0.0 - 1.0
    public var volume: Double = 0.5
    public var isMuted: Bool = false
    public var theme: AppTheme = .system
    /// Read "now playing" titles of Icecast streams (opens a second connection to the stream).
    public var showSongTitles: Bool = true
    /// Raw value of the last open section.
    public var lastPage: String?

    public init() {}

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lastStationId = try c.decodeIfPresent(String.self, forKey: .lastStationId)
        volume = try c.decodeIfPresent(Double.self, forKey: .volume) ?? 0.5
        isMuted = try c.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        theme = try c.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system
        showSongTitles = try c.decodeIfPresent(Bool.self, forKey: .showSongTitles) ?? true
        lastPage = try c.decodeIfPresent(String.self, forKey: .lastPage)
    }
}

public enum AppTheme: String, Codable, Sendable, CaseIterable {
    case system
    case light
    case dark
}
