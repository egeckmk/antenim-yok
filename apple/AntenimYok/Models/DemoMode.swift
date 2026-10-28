#if DEBUG
import AntenimYokCore
import Foundation
#if os(macOS)
import AppKit
#endif

/// Debug-only mode for the App Store screenshots (`apple/scripts/screenshots.sh`).
///
///     -demoMode  -demoSection favorites|discover|settings  -demoTheme light|dark  -demoPlay
///
/// It uses real stations from Radio Browser (the best voted ones that have a logo); without a network
/// a small embedded sample is shown instead. Favorites and settings go to a temporary folder.
struct DemoMode {
    let directory: URL
    let section: AppSection
    let theme: AppTheme
    let play: Bool

    init?(arguments: [String]) {
        guard arguments.contains("-demoMode") else { return nil }
        func value(_ flag: String) -> String? {
            arguments.firstIndex(of: flag).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        }
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("AntenimYokDemo", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("favorites.json"))
        section = value("-demoSection").flatMap(AppSection.init(rawValue:)) ?? .favorites
        theme = value("-demoTheme").flatMap(AppTheme.init(rawValue:)) ?? .light
        play = arguments.contains("-demoPlay")
    }

    func configure(_ settings: inout AppSettings) {
        settings.theme = theme
        settings.lastPage = section.rawValue
        settings.volume = 0.6
        settings.isMuted = false
    }

    @MainActor
    func run(model: AppModel) async {
        let stations = await Self.stations()
        model.demoSetFavorites(Array(stations.prefix(8)))
        model.section = section
        #if os(macOS)
        await Self.sizeMainWindow()
        #endif
        if play, let first = model.favorites.first {
            model.play(first)
        }
    }

    private static func stations() async -> [Station] {
        let client = RadioBrowserClient()
        if let found = try? await client.stations(countryCode: AntenimYokCore.countryCode) {
            let candidates = DiscoverCatalog(found).stations
                .filter { ($0.station.logo ?? "").hasPrefix("https") }
                .prefix(40)
                .map(\.station)
            // Keep the ones whose logo really loads (some logo hosts are down), in popularity order.
            let working = await withTaskGroup(of: (Int, Station?).self) { group in
                for (index, station) in candidates.enumerated() {
                    group.addTask { (index, await logoLoads(station) ? station : nil) }
                }
                var result: [(Int, Station)] = []
                for await (index, station) in group { if let station { result.append((index, station)) } }
                return result.sorted { $0.0 < $1.0 }.map(\.1)
            }
            if working.count >= 4 { return Array(working.prefix(8)) }
        }
        return ["Örnek Radyo Pop", "Örnek Radyo Türkü", "Örnek Radyo Nostalji", "Örnek Radyo Haber"].enumerated().map {
            Station(id: "demo-\($0.offset)", name: $0.element, streams: [StationStream(url: "https://example.invalid/\($0.offset)")])
        }
    }

    private static func logoLoads(_ station: Station) async -> Bool {
        guard let logo = station.logo, let url = URL(string: logo) else { return false }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("AntenimYok", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return false }
        return data.count > 500 && (response.mimeType ?? "").hasPrefix("image")
    }

    #if os(macOS)
    /// 1440 x 900 pt = 2880 x 1800 px on a Retina screen, a size the Mac App Store accepts.
    @MainActor
    private static func sizeMainWindow() async {
        try? await Task.sleep(for: .seconds(1))
        guard let window = NSApplication.shared.windows.first(where: { $0.canBecomeMain }) else { return }
        window.setFrame(NSRect(x: 40, y: 60, width: 1440, height: 900), display: true)
    }
    #endif
}
#endif
