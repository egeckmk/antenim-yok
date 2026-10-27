using System.Net.Http.Json;
using System.Text.Json.Serialization;
using AntenimYok.Core.Stations;

namespace AntenimYok.Core.Discovery;

/// <summary>A station found on Radio Browser, with the extras Discover shows and filters on.</summary>
public sealed record DiscoveredStation(Station Station, IReadOnlyList<string> Tags, int Votes);

/// <summary>Reads stations from the Radio Browser API (https://api.radio-browser.info).</summary>
public sealed class RadioBrowserClient(HttpClient http)
{
    private const string BaseUrl = "https://all.api.radio-browser.info/json";

    /// <summary>All working stations of a country, most voted first.</summary>
    public async Task<IReadOnlyList<DiscoveredStation>> GetByCountryAsync(string countryCode, CancellationToken cancellationToken = default)
    {
        var url = $"{BaseUrl}/stations/bycountrycodeexact/{Uri.EscapeDataString(countryCode)}?hidebroken=true&order=votes&reverse=true";
        var raw = await http.GetFromJsonAsync<List<RadioBrowserStation>>(url, cancellationToken) ?? [];
        return raw
            .Select(ToDiscovered)
            .OfType<DiscoveredStation>()
            .ToList();
    }

    internal static DiscoveredStation? ToDiscovered(RadioBrowserStation s)
    {
        var url = string.IsNullOrWhiteSpace(s.UrlResolved) ? s.Url : s.UrlResolved;
        var name = s.Name?.Trim();
        if (string.IsNullOrWhiteSpace(url) || string.IsNullOrEmpty(name) || string.IsNullOrEmpty(s.StationUuid)
            || !Uri.TryCreate(url, UriKind.Absolute, out _))
        {
            return null;
        }

        var station = new Station
        {
            Id = "rb-" + s.StationUuid,
            Name = name,
            Logo = string.IsNullOrWhiteSpace(s.Favicon) ? null : s.Favicon,
            Homepage = string.IsNullOrWhiteSpace(s.Homepage) ? null : s.Homepage,
            RadioBrowserUuid = s.StationUuid,
            Streams =
            [
                new StationStream
                {
                    Url = url,
                    Type = s.Hls == 1 ? StreamType.Hls : StreamType.Icecast,
                    Codec = string.IsNullOrWhiteSpace(s.Codec) || s.Codec == "UNKNOWN" ? null : s.Codec,
                    Bitrate = s.Bitrate > 0 ? s.Bitrate : null,
                },
            ],
        };
        var tags = (s.Tags ?? "")
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
        return new DiscoveredStation(station, tags, s.Votes);
    }

    internal sealed record RadioBrowserStation
    {
        [JsonPropertyName("stationuuid")] public string? StationUuid { get; init; }
        [JsonPropertyName("name")] public string? Name { get; init; }
        [JsonPropertyName("url")] public string? Url { get; init; }
        [JsonPropertyName("url_resolved")] public string? UrlResolved { get; init; }
        [JsonPropertyName("homepage")] public string? Homepage { get; init; }
        [JsonPropertyName("favicon")] public string? Favicon { get; init; }
        [JsonPropertyName("tags")] public string? Tags { get; init; }
        [JsonPropertyName("codec")] public string? Codec { get; init; }
        [JsonPropertyName("bitrate")] public int Bitrate { get; init; }
        [JsonPropertyName("hls")] public int Hls { get; init; }
        [JsonPropertyName("votes")] public int Votes { get; init; }
    }
}
