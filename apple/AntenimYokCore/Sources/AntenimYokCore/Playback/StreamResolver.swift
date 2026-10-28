import Foundation

public protocol StreamResolving: Sendable {
    /// Returns the URL the player should open (playlist files are expanded to their first entry).
    func resolve(_ stream: StationStream) async throws -> URL
}

public struct PlaylistError: Error, Equatable, Sendable {
    public var url: URL
}

public struct StreamResolver: StreamResolving {
    /// A misnamed URL could be an endless audio stream, so at most this much is read.
    public static let maxPlaylistBytes = 64 * 1024

    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport = URLSessionTransport()) {
        self.transport = transport
    }

    public func resolve(_ stream: StationStream) async throws -> URL {
        guard let url = URL(string: stream.url) else { throw URLError(.badURL) }
        guard stream.type != .hls, let format = PlaylistParser.detectFormat(of: url) else { return url }

        var request = URLRequest(url: url)
        request.setValue("AntenimYok", forHTTPHeaderField: "User-Agent")
        let response = try await transport.stream(for: request)
        guard (200..<300).contains(response.statusCode) else { throw HTTPError(statusCode: response.statusCode) }

        var body = Data()
        for try await chunk in response.chunks {
            body.append(chunk)
            if body.count >= Self.maxPlaylistBytes { break }
        }
        let content = String(decoding: body.prefix(Self.maxPlaylistBytes), as: UTF8.self)
        guard let first = PlaylistParser.parse(content, format: format, baseURL: response.finalURL ?? url).first else {
            throw PlaylistError(url: url)
        }
        return first
    }
}
