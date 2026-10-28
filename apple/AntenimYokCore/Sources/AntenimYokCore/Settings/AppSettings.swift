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
    /// Mac: closing the window keeps playing from the menu bar (otherwise closing the last window quits).
    public var keepPlayingInMenuBar: Bool = true
    /// Mac: where the mini player window was left (bottom-left origin of the window).
    public var miniPlayerPosition: WindowPosition?

    public init() {}

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lastStationId = try c.decodeIfPresent(String.self, forKey: .lastStationId)
        volume = try c.decodeIfPresent(Double.self, forKey: .volume) ?? 0.5
        isMuted = try c.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        theme = try c.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system
        showSongTitles = try c.decodeIfPresent(Bool.self, forKey: .showSongTitles) ?? true
        lastPage = try c.decodeIfPresent(String.self, forKey: .lastPage)
        keepPlayingInMenuBar = try c.decodeIfPresent(Bool.self, forKey: .keepPlayingInMenuBar) ?? true
        miniPlayerPosition = try c.decodeIfPresent(WindowPosition.self, forKey: .miniPlayerPosition)
    }
}

public enum AppTheme: String, Codable, Sendable, CaseIterable {
    case system
    case light
    case dark
}

public struct WindowPosition: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}
