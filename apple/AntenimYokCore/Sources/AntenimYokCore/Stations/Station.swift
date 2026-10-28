import Foundation

/// A radio station. The JSON shape is shared with the Windows app's `favorites.json`
/// (camelCase keys, `streams` in priority order, nil fields omitted).
public struct Station: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var logo: String?
    public var logoOnDarkOnly: Bool
    public var homepage: String?
    public var radioBrowserUuid: String?
    /// Streams in priority order; the first one that opens wins.
    public var streams: [StationStream]

    public init(
        id: String,
        name: String,
        logo: String? = nil,
        logoOnDarkOnly: Bool = false,
        homepage: String? = nil,
        radioBrowserUuid: String? = nil,
        streams: [StationStream] = []
    ) {
        self.id = id
        self.name = name
        self.logo = logo
        self.logoOnDarkOnly = logoOnDarkOnly
        self.homepage = homepage
        self.radioBrowserUuid = radioBrowserUuid
        self.streams = streams
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        logo = try c.decodeIfPresent(String.self, forKey: .logo)
        logoOnDarkOnly = try c.decodeIfPresent(Bool.self, forKey: .logoOnDarkOnly) ?? false
        homepage = try c.decodeIfPresent(String.self, forKey: .homepage)
        radioBrowserUuid = try c.decodeIfPresent(String.self, forKey: .radioBrowserUuid)
        streams = try c.decodeIfPresent([StationStream].self, forKey: .streams) ?? []
    }

    /// Up to two initials, used when there is no logo ("Kafa Radyo" -> "KR").
    public var initials: String {
        let turkish = Locale(identifier: "tr_TR")
        return name
            .split(separator: " ")
            .filter { $0.first.map { $0.isLetter || $0.isNumber } ?? false }
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0).uppercased(with: turkish) }
            .joined()
    }
}

public struct StationStream: Codable, Hashable, Sendable {
    public var url: String
    public var type: StreamType
    public var codec: String?
    public var bitrate: Int?

    public init(url: String, type: StreamType = .icecast, codec: String? = nil, bitrate: Int? = nil) {
        self.url = url
        self.type = type
        self.codec = codec
        self.bitrate = bitrate
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        url = try c.decode(String.self, forKey: .url)
        type = try c.decodeIfPresent(StreamType.self, forKey: .type) ?? .icecast
        codec = try c.decodeIfPresent(String.self, forKey: .codec)
        bitrate = try c.decodeIfPresent(Int.self, forKey: .bitrate)
    }
}

/// Raw values match the Windows JSON (`"icecast"`, `"hls"`).
public enum StreamType: String, Codable, Hashable, Sendable {
    case icecast
    case hls
}
