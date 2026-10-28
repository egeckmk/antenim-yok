import Foundation
import Testing
@testable import AntenimYokCore

@Suite struct StationTests {
    @Test(arguments: [
        ("Kafa Radyo", "KR"),
        ("Virgin Radio Türkiye", "VR"),
        ("Metro FM", "MF"),
        ("idil", "İ"),
    ])
    func initialsUseFirstTwoWords(name: String, expected: String) {
        #expect(Station(id: "x", name: name).initials == expected)
    }

    @Test func decodesWindowsJsonWithMissingOptionalFields() throws {
        let json = #"{"id":"a","name":"A","streams":[{"url":"https://x/a","unverified":true}]}"#
        let station = try JSONDecoder().decode(Station.self, from: Data(json.utf8))
        #expect(station.id == "a")
        #expect(station.logo == nil)
        #expect(station.logoOnDarkOnly == false)
        #expect(station.streams.first?.type == .icecast)
    }

    @Test func decodesStreamTypeRawValuesAndFullFields() throws {
        let json = """
        {"id":"rb-1","name":"R","logo":"https://l/x.png","logoOnDarkOnly":true,"homepage":"https://h",
         "radioBrowserUuid":"1","streams":[{"url":"https://x/p.m3u8","type":"hls","codec":"AAC","bitrate":96}]}
        """
        let s = try JSONDecoder().decode(Station.self, from: Data(json.utf8))
        #expect(s.logoOnDarkOnly)
        #expect(s.radioBrowserUuid == "1")
        #expect(s.streams[0] == StationStream(url: "https://x/p.m3u8", type: .hls, codec: "AAC", bitrate: 96))
    }

    @Test func encodeRoundTripUsesCamelCaseAndOmitsNil() throws {
        let station = Station(id: "a", name: "A", logoOnDarkOnly: true, streams: [StationStream(url: "https://x", type: .hls)])
        let data = try JSONEncoder().encode(station)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"logoOnDarkOnly\":true"))
        #expect(text.contains("\"hls\""))
        #expect(!text.contains("\"logo\""))
        #expect(!text.contains("homepage"))
        #expect(try JSONDecoder().decode(Station.self, from: data) == station)
    }
}

@Suite struct StationSearchTests {
    @Test(arguments: [
        ("Power Türk", "power türk", true),
        ("Power Türk", "turk", true),
        ("Power Türk", "türk power", true),
        ("Show Radyo", "RADYO", true),
        ("İstanbul FM", "istanbul", true),
        ("Radyo Fenomen", "  ", true),
        ("Metro FM", "kafa", false),
        ("Power FM", "power türk", false),
    ])
    func matches(name: String, query: String, expected: Bool) {
        #expect(StationSearch.matches(Station(id: "x", name: name), query: query) == expected)
    }

    @Test func nilQueryMatchesEverything() {
        #expect(StationSearch.matches(Station(id: "x", name: "Radyo Fenomen"), query: nil))
    }

    @Test func foldDropsAccentsAndDotlessI() {
        #expect(StationSearch.fold("ÇAĞRI Şükrü ÖĞÜT ıSI") == "cagri sukru ogut isi")
    }
}
