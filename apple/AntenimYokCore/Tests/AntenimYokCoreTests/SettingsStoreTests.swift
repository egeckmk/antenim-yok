import Foundation
import Testing
@testable import AntenimYokCore

@Suite struct SettingsStoreTests {
    let dir = makeTempDirectory()
    var url: URL { dir.appendingPathComponent("settings.json") }

    func store(delay: Duration = .seconds(3600), sleeper: any Sleeper = TaskSleeper()) -> SettingsStore {
        SettingsStore(url: url, saveDelay: delay, sleeper: sleeper)
    }

    @Test func missingFileUsesDefaults() {
        let s = store().current
        #expect(s.lastStationId == nil)
        #expect(s.volume == 0.5)
        #expect(s.showSongTitles)
        #expect(s.theme == .system)
    }

    @Test func flushPersistsAndReloads() throws {
        let s = store()
        s.update {
            $0.lastStationId = "kafa-radyo"
            $0.volume = 0.8
            $0.isMuted = true
            $0.theme = .light
            $0.showSongTitles = false
            $0.lastPage = "discover"
        }
        s.flush()

        let r = store().current
        #expect(r.lastStationId == "kafa-radyo")
        #expect(r.volume == 0.8)
        #expect(r.isMuted)
        #expect(r.theme == .light)
        #expect(!r.showSongTitles)
        #expect(r.lastPage == "discover")
        #expect(try String(contentsOf: url, encoding: .utf8).contains("\"light\""))
    }

    @Test func updateDoesNotWriteBeforeDelay() {
        let s = store()
        s.update { $0.volume = 0.3 }
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(s.current.volume == 0.3)
    }

    @Test func updateSavesAfterDelay() async throws {
        let s = store(delay: .milliseconds(20))
        s.update { $0.volume = 0.3 }
        for _ in 0..<100 where !FileManager.default.fileExists(atPath: url.path) {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(store().current.volume == 0.3)
    }

    @Test func rapidUpdatesWriteOnlyLatestValue() async throws {
        let s = store(delay: .milliseconds(50))
        for v in stride(from: 0.1, through: 0.9, by: 0.1) { s.update { $0.volume = v } }
        try await Task.sleep(for: .milliseconds(400))
        #expect(abs(store().current.volume - 0.9) < 0.0001)
    }

    @Test func noOpUpdateSchedulesNothing() {
        let s = store()
        s.update { $0.volume = 0.5 }
        s.flush()
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func corruptFileUsesDefaults() throws {
        try Data("{ not json".utf8).write(to: url)
        #expect(store().current == AppSettings())
    }

    @Test func partialFileFillsDefaults() throws {
        try Data(#"{"volume":0.9}"#.utf8).write(to: url)
        let s = store().current
        #expect(s.volume == 0.9)
        #expect(s.showSongTitles)
    }
}
