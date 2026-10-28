import Foundation
import Testing
@testable import AntenimYokCore

@Suite struct MenuBarMenuTests {
    let favs = [Station(id: "a", name: "A FM"), Station(id: "b", name: "B FM")]

    @Test func noFavoritesStillHasControls() {
        let items = MenuBarMenu.items(favorites: [], playingStationId: nil, isActive: false, hasStationToPlay: false)
        #expect(items == [.playPause(title: "Çal", isEnabled: false), .showWindow, .separator, .quit])
    }

    @Test func playingFavoriteIsMarkedAndButtonSaysStop() {
        let items = MenuBarMenu.items(favorites: favs, playingStationId: "b", isActive: true, hasStationToPlay: true)
        #expect(items == [
            .station(id: "a", name: "A FM", isPlaying: false),
            .station(id: "b", name: "B FM", isPlaying: true),
            .separator,
            .playPause(title: "Durdur", isEnabled: true),
            .showWindow, .separator, .quit,
        ])
    }

    @Test func stoppedStationIsNotMarkedPlaying() {
        let items = MenuBarMenu.items(favorites: favs, playingStationId: "b", isActive: false, hasStationToPlay: true)
        #expect(items[1] == .station(id: "b", name: "B FM", isPlaying: false))
        #expect(items.contains(.playPause(title: "Çal", isEnabled: true)))
    }

    @Test func stopIsEnabledWhileActiveEvenWithoutStation() {
        let items = MenuBarMenu.items(favorites: [], playingStationId: nil, isActive: true, hasStationToPlay: false)
        #expect(items.first == .playPause(title: "Durdur", isEnabled: true))
    }

    @Test func titles() {
        #expect(MenuBarItem.showWindow.title == "Pencereyi göster")
        #expect(MenuBarItem.quit.title == "Çıkış")
        #expect(MenuBarItem.separator.title == nil)
        #expect(MenuBarItem.station(id: "a", name: "A", isPlaying: false).title == "A")
    }

    @Test func quitsOnLastWindowOnlyWhenNotKeepingInMenuBar() {
        #expect(MenuBarMenu.quitsWhenLastWindowCloses(keepPlayingInMenuBar: false))
        #expect(!MenuBarMenu.quitsWhenLastWindowCloses(keepPlayingInMenuBar: true))
    }
}

@Suite struct MiniPlayerPlacementTests {
    let main = PlacementRect(x: 0, y: 0, width: 1440, height: 900)
    let second = PlacementRect(x: 1440, y: 0, width: 1920, height: 1080)
    let size = (width: 300.0, height: 100.0)

    @Test func noSavedPositionGoesBottomRightOfFirstScreen() {
        let p = MiniPlayerPlacement.origin(saved: nil, size: size, visibleFrames: [main, second])
        #expect(p == WindowPosition(x: 1440 - 300 - 24, y: 24))
    }

    @Test func savedPositionOnScreenIsKept() {
        let saved = WindowPosition(x: 500, y: 400)
        #expect(MiniPlayerPlacement.origin(saved: saved, size: size, visibleFrames: [main]) == saved)
    }

    @Test func savedOnSecondScreenIsKeptWhileItExists() {
        let saved = WindowPosition(x: 2000, y: 300)
        #expect(MiniPlayerPlacement.origin(saved: saved, size: size, visibleFrames: [main, second]) == saved)
    }

    @Test func unpluggedScreenFallsBackToFirstScreenCorner() {
        let saved = WindowPosition(x: 2000, y: 300)
        let p = MiniPlayerPlacement.origin(saved: saved, size: size, visibleFrames: [main])
        #expect(p == WindowPosition(x: 1440 - 300 - 24, y: 24))
    }

    @Test func partlyOffscreenIsClampedInside() {
        let p = MiniPlayerPlacement.origin(saved: WindowPosition(x: 1350, y: 850), size: size, visibleFrames: [main])
        #expect(p == WindowPosition(x: 1140, y: 800))
        let q = MiniPlayerPlacement.origin(saved: WindowPosition(x: -100, y: -50), size: size, visibleFrames: [main])
        #expect(q == WindowPosition(x: 0, y: 0))
    }

    @Test func straddlingScreensClampsToTheOneWithMostOverlap() {
        // 250 px on main, 50 px on second -> main wins.
        let p = MiniPlayerPlacement.origin(saved: WindowPosition(x: 1190, y: 300), size: size, visibleFrames: [main, second])
        #expect(p == WindowPosition(x: 1140, y: 300))
    }

    @Test func screenSmallerThanWindowPinsToBottomLeft() {
        let tiny = PlacementRect(x: 10, y: 20, width: 200, height: 50)
        let p = MiniPlayerPlacement.origin(saved: WindowPosition(x: 50, y: 30), size: size, visibleFrames: [tiny])
        #expect(p == WindowPosition(x: 10, y: 20))
    }

    @Test func noScreensReturnsSavedUnchanged() {
        let saved = WindowPosition(x: 5, y: 6)
        #expect(MiniPlayerPlacement.origin(saved: saved, size: size, visibleFrames: []) == saved)
        #expect(MiniPlayerPlacement.origin(saved: nil, size: size, visibleFrames: []) == nil)
    }

    @Test func touchingEdgeOnlyDoesNotCountAsOverlap() {
        let saved = WindowPosition(x: 1440, y: 2000) // above both screens
        let p = MiniPlayerPlacement.origin(saved: saved, size: size, visibleFrames: [main])
        #expect(p == WindowPosition(x: 1116, y: 24))
    }
}

@Suite struct MenuBarSettingsTests {
    @Test func oldSettingsJsonDefaultsToKeepPlaying() throws {
        let s = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"volume":0.2}"#.utf8))
        #expect(s.keepPlayingInMenuBar)
        #expect(s.miniPlayerPosition == nil)
    }

    @Test func newFieldsRoundTrip() throws {
        var s = AppSettings()
        s.keepPlayingInMenuBar = false
        s.miniPlayerPosition = WindowPosition(x: 12.5, y: -3)
        let back = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(s))
        #expect(back == s)
    }
}
