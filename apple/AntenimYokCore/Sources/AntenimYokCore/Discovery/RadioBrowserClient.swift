import Foundation

/// A station found on Radio Browser, with the extras Discover shows and filters on.
public struct DiscoveredStation: Hashable, Sendable, Identifiable {
    public var station: Station
    public var tags: [String]
    public var votes: Int

    public var id: String { station.id }

    public init(station: Station, tags: [String] = [], votes: Int = 0) {
        self.station = station
        self.tags = tags
        self.votes = votes
    }

    /// "pop · turkish · MP3 128 kbps" - what the list shows under the name.
    public var summary: String {
        var parts = Array(tags.prefix(3))
        if let stream = station.streams.first, let codec = stream.codec {
            parts.append(stream.bitrate.map { "\(codec) \($0) kbps" } ?? codec)
        }
        return parts.joined(separator: " · ")
    }
}

/// Reads stations from the Radio Browser API (https://api.radio-browser.info).
public struct RadioBrowserClient: Sendable {
    public static let defaultBaseURL = URL(string: "https://all.api.radio-browser.info/json")!

    private let transport: any HTTPTransport
    private let baseURL: URL

    public init(transport: any HTTPTransport = URLSessionTransport(), baseURL: URL = RadioBrowserClient.defaultBaseURL) {
        self.transport = transport
        self.baseURL = baseURL
    }

    /// All working stations of a country, most voted first (as the server sorts them).
    public func stations(countryCode: String) async throws -> [DiscoveredStation] {
        let escaped = countryCode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? countryCode
        var components = URLComponents(
            url: baseURL.appendingPathComponent("stations/bycountrycodeexact/\(escaped)"),
            resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "hidebroken", value: "true"),
            URLQueryItem(name: "order", value: "votes"),
            URLQueryItem(name: "reverse", value: "true"),
        ]
        return try await fetch(components.url!)
    }

    /// Server-side name search within a country.
    public func search(name: String, countryCode: String) async throws -> [DiscoveredStation] {
        var components = URLComponents(url: baseURL.appendingPathComponent("stations/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "countrycode", value: countryCode),
            URLQueryItem(name: "hidebroken", value: "true"),
            URLQueryItem(name: "order", value: "votes"),
            URLQueryItem(name: "reverse", value: "true"),
        ]
        return try await fetch(components.url!)
    }

    private func fetch(_ url: URL) async throws -> [DiscoveredStation] {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("AntenimYok", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let response = try await transport.data(for: request)
        guard (200..<300).contains(response.statusCode) else { throw HTTPError(statusCode: response.statusCode) }
        return try Self.decode(response.data)
    }

    /// Decodes the API's JSON array; entries without a usable URL, name or uuid are dropped.
    public static func decode(_ data: Data) throws -> [DiscoveredStation] {
        try JSONDecoder().decode([RawStation].self, from: data).compactMap(\.discovered)
    }

    struct RawStation: Decodable {
        var stationuuid: String?
        var name: String?
        var url: String?
        var url_resolved: String?
        var homepage: String?
        var favicon: String?
        var tags: String?
        var codec: String?
        var bitrate: Int?
        var hls: Int?
        var votes: Int?

        var discovered: DiscoveredStation? {
            let streamURL = [url_resolved, url]
                .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty }
            let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let streamURL, let parsed = URL(string: streamURL), parsed.scheme != nil, parsed.host != nil,
                  let trimmedName, !trimmedName.isEmpty,
                  let uuid = stationuuid, !uuid.isEmpty
            else { return nil }

            func clean(_ value: String?) -> String? {
                guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
                return value
            }

            let station = Station(
                id: "rb-" + uuid,
                name: trimmedName,
                logo: clean(favicon),
                homepage: clean(homepage),
                radioBrowserUuid: uuid,
                streams: [StationStream(
                    url: streamURL,
                    type: hls == 1 ? .hls : .icecast,
                    codec: clean(codec).flatMap { $0 == "UNKNOWN" ? nil : $0 },
                    bitrate: (bitrate ?? 0) > 0 ? bitrate : nil)])

            var seen = Set<String>()
            let tagList = (tags ?? "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
            return DiscoveredStation(station: station, tags: tagList, votes: votes ?? 0)
        }
    }
}
