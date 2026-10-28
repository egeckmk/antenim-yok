import Foundation

public protocol IcyMetadataReading: Sendable {
    /// Yields the stream's "now playing" title each time it changes. Finishes if the stream has no metadata.
    func titles(for streamURL: URL) -> AsyncThrowingStream<String, any Error>
}

/// Reads SHOUTcast/Icecast in-band metadata ("StreamTitle='Artist - Song';") over its own connection.
/// The audio itself is played by `AVPlayer`, which is not asked for these titles here.
public struct IcyMetadataReader: IcyMetadataReading {
    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport = URLSessionTransport()) {
        self.transport = transport
    }

    public func titles(for streamURL: URL) -> AsyncThrowingStream<String, any Error> {
        let transport = transport
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: streamURL)
                    request.setValue("1", forHTTPHeaderField: "Icy-MetaData")
                    request.setValue("AntenimYok", forHTTPHeaderField: "User-Agent")
                    let response = try await transport.stream(for: request)
                    guard (200..<300).contains(response.statusCode) else { throw HTTPError(statusCode: response.statusCode) }
                    guard let metaInt = response.headers["icy-metaint"].flatMap({ Int($0) }), metaInt > 0 else {
                        continuation.finish()
                        return
                    }

                    var parser = IcyBlockParser(metaInterval: metaInt)
                    var last: String?
                    for try await chunk in response.chunks {
                        for title in parser.feed(chunk) where title != last {
                            last = title
                            continuation.yield(title)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Extracts StreamTitle from a metadata block; nil if absent or blank.
    public static func parseStreamTitle(_ block: Data) -> String? {
        let trimmed = block.reversed().drop { $0 == 0 }.reversed()
        let text = decode(Data(trimmed))
        let start = "StreamTitle='"
        guard let from = text.range(of: start)?.upperBound else { return nil }
        let rest = text[from...]
        let end = rest.range(of: "';")?.lowerBound ?? rest.lastIndex(of: "'") ?? rest.endIndex
        guard end >= from else { return nil }
        let title = text[from..<end]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    // Most Turkish stations send UTF-8; older servers send Windows-1254.
    private static func decode(_ data: Data) -> String {
        String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1254) ?? ""
    }
}

/// Splits the byte stream into audio (skipped) and metadata blocks: `metaInterval` audio bytes,
/// one length byte (x16), then that many metadata bytes, repeated.
struct IcyBlockParser {
    private enum Phase {
        case audio(remaining: Int)
        case length
        case metadata(remaining: Int)
    }

    private let metaInterval: Int
    private var phase: Phase
    private var block = Data()

    init(metaInterval: Int) {
        self.metaInterval = metaInterval
        phase = .audio(remaining: metaInterval)
    }

    /// Feeds the next chunk; returns the titles of any metadata blocks completed in it.
    mutating func feed(_ chunk: Data) -> [String] {
        var titles: [String] = []
        var data = Data(chunk)
        while !data.isEmpty {
            switch phase {
            case .audio(let remaining):
                let take = min(remaining, data.count)
                data.removeFirst(take)
                phase = take == remaining ? .length : .audio(remaining: remaining - take)
            case .length:
                let length = Int(data.removeFirst()) * 16
                block.removeAll(keepingCapacity: true)
                phase = length == 0 ? .audio(remaining: metaInterval) : .metadata(remaining: length)
            case .metadata(let remaining):
                let take = min(remaining, data.count)
                block.append(data.prefix(take))
                data.removeFirst(take)
                if take == remaining {
                    if let title = IcyMetadataReader.parseStreamTitle(block) { titles.append(title) }
                    phase = .audio(remaining: metaInterval)
                } else {
                    phase = .metadata(remaining: remaining - take)
                }
            }
        }
        return titles
    }
}
