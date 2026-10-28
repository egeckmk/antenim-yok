import Foundation

/// A Discover filter chip. Radio Browser tags are free text ("pop", "turkish pop", "pop music"...),
/// so each genre lists the keywords that count as a match.
public struct Genre: Hashable, Sendable, Identifiable {
    public var name: String
    public var keywords: [String]

    public var id: String { name }

    public init(name: String, keywords: [String]) {
        self.name = name
        self.keywords = keywords
    }

    public static let all = Genre(name: "Tümü", keywords: [])

    public static let defaults: [Genre] = [
        all,
        Genre(name: "Pop", keywords: ["pop"]),
        Genre(name: "Rock", keywords: ["rock", "metal"]),
        Genre(name: "Türkü / Halk", keywords: ["folk", "türkü", "turku", "halk"]),
        Genre(name: "Türk Sanat", keywords: ["sanat", "fasıl", "fasil", "ottoman", "turkish classical"]),
        Genre(name: "Arabesk", keywords: ["arabesk", "arabesque"]),
        Genre(name: "Nostalji", keywords: ["60s", "70s", "80s", "90s", "00s", "oldies", "nostalji"]),
        Genre(name: "Caz", keywords: ["jazz", "caz", "blues"]),
        Genre(name: "Klasik", keywords: ["classical", "klasik"]),
        Genre(name: "Elektronik", keywords: ["electronic", "house", "dance", "techno", "trance"]),
        Genre(name: "Haber / Konuşma", keywords: ["news", "haber", "talk", "spor", "sport"]),
        Genre(name: "Dini", keywords: ["islamic", "religious", "ilahi", "dini", "quran", "kuran"]),
    ]

    public func matches(_ station: DiscoveredStation) -> Bool {
        guard !keywords.isEmpty else { return true }
        let folded = keywords.map(StationSearch.fold)
        return station.tags.contains { tag in
            let foldedTag = StationSearch.fold(tag)
            return folded.contains { foldedTag.contains($0) }
        }
    }
}
