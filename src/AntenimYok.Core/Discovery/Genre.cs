using AntenimYok.Core.Stations;

namespace AntenimYok.Core.Discovery;

/// <summary>
/// A Discover filter chip. Radio Browser tags are free text ("pop", "turkish pop", "pop music"…),
/// so each genre lists the keywords that count as a match.
/// </summary>
public sealed record Genre(string Name, IReadOnlyList<string> Keywords)
{
    public static readonly Genre All = new("Tümü", []);

    public static readonly IReadOnlyList<Genre> Defaults =
    [
        All,
        new("Pop", ["pop"]),
        new("Rock", ["rock", "metal"]),
        new("Türkü / Halk", ["folk", "türkü", "turku", "halk"]),
        new("Türk Sanat", ["sanat", "fasıl", "fasil", "ottoman", "turkish classical"]),
        new("Arabesk", ["arabesk", "arabesque"]),
        new("Nostalji", ["60s", "70s", "80s", "90s", "00s", "oldies", "nostalji"]),
        new("Caz", ["jazz", "caz", "blues"]),
        new("Klasik", ["classical", "klasik"]),
        new("Elektronik", ["electronic", "house", "dance", "techno", "trance"]),
        new("Haber / Konuşma", ["news", "haber", "talk", "spor", "sport"]),
        new("Dini", ["islamic", "religious", "ilahi", "dini", "quran", "kuran"]),
    ];

    public bool Matches(DiscoveredStation station) =>
        Keywords.Count == 0
        || station.Tags.Any(tag => Keywords.Any(k => StationSearch.Fold(tag).Contains(StationSearch.Fold(k), StringComparison.Ordinal)));

    public override string ToString() => Name;
}
