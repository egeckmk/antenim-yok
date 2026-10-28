import Foundation
import Observation

/// Follows `RadioPlayer`: while an Icecast stream plays, reads its song titles (`IcyMetadataReading`);
/// otherwise the title is nil. HLS streams have no titles here.
@MainActor
@Observable
public final class SongTitleMonitor {
    public private(set) var currentTitle: String?

    /// Off: no extra connection is opened (it roughly doubles the data used).
    public var isEnabled: Bool = true {
        didSet { if oldValue != isEnabled { playerStateChanged() } }
    }

    /// Wait before reconnecting when the metadata connection drops while the radio still plays.
    public let retryDelay: Duration

    @ObservationIgnored private let player: RadioPlayer
    @ObservationIgnored private let reader: any IcyMetadataReading
    @ObservationIgnored private let sleeper: any Sleeper
    @ObservationIgnored private var readTask: Task<Void, Never>?
    @ObservationIgnored private var readingURL: URL?

    public init(
        player: RadioPlayer,
        reader: any IcyMetadataReading,
        sleeper: any Sleeper = TaskSleeper(),
        retryDelay: Duration = .seconds(20)
    ) {
        self.player = player
        self.reader = reader
        self.sleeper = sleeper
        self.retryDelay = retryDelay
        player.observeState { [weak self] in self?.playerStateChanged() }
    }

    private func playerStateChanged() {
        let url: URL? = if isEnabled, player.state == .playing, player.currentStream?.type == .icecast {
            player.currentURL
        } else {
            nil
        }

        guard url != readingURL else { return }
        readTask?.cancel()
        readTask = nil
        readingURL = url
        setTitle(nil)
        if let url {
            readTask = Task { await self.readLoop(url) }
        }
    }

    private func readLoop(_ url: URL) async {
        while !Task.isCancelled {
            do {
                for try await title in reader.titles(for: url) {
                    if Task.isCancelled { return }
                    setTitle(title)
                }
                return // Stream has no metadata (or ended): nothing more to read.
            } catch {
                if Task.isCancelled { return }
            }

            do { try await sleeper.sleep(for: retryDelay) } catch { return }
        }
    }

    private func setTitle(_ title: String?) {
        if title != currentTitle { currentTitle = title }
    }
}
