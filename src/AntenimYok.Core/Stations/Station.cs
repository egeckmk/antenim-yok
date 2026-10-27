using System.Globalization;
using System.Text.Json.Serialization;

namespace AntenimYok.Core.Stations;

public sealed record Station
{
    public required string Id { get; init; }
    public required string Name { get; init; }
    public string? Logo { get; init; }
    public bool LogoOnDarkOnly { get; init; }
    public string? Homepage { get; init; }
    public string? RadioBrowserUuid { get; init; }

    /// <summary>Streams in priority order; the first one that opens wins.</summary>
    public IReadOnlyList<StationStream> Streams { get; init; } = [];

    /// <summary>Up to two initials, used when there is no logo ("Kafa Radyo" → "KR").</summary>
    [JsonIgnore]
    public string Initials
    {
        get
        {
            var culture = CultureInfo.GetCultureInfo("tr-TR");
            var letters = Name
                .Split(' ', StringSplitOptions.RemoveEmptyEntries)
                .Where(w => char.IsLetterOrDigit(w[0]))
                .Take(2)
                .Select(w => char.ToUpper(w[0], culture));
            return string.Concat(letters);
        }
    }

    // List items use ToString for their accessible name (Narrator).
    public override string ToString() => Name;
}

public sealed record StationStream
{
    public required string Url { get; init; }
    public StreamType Type { get; init; } = StreamType.Icecast;
    public string? Codec { get; init; }
    public int? Bitrate { get; init; }

    /// <summary>Guessed URL that has not been tried yet.</summary>
    public bool Unverified { get; init; }
}

public enum StreamType
{
    Icecast,
    Hls,
}
