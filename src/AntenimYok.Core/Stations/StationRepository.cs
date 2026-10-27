using System.Text.Json;
using System.Text.Json.Serialization;

namespace AntenimYok.Core.Stations;

/// <summary>Reads the shared <c>stations.json</c> list (embedded copy or any stream).</summary>
public sealed class StationRepository
{
    private const string EmbeddedResourceName = "stations.json";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };

    public async Task<IReadOnlyList<Station>> LoadEmbeddedAsync(CancellationToken cancellationToken = default)
    {
        await using var stream = typeof(StationRepository).Assembly.GetManifestResourceStream(EmbeddedResourceName)
            ?? throw new InvalidOperationException($"Embedded resource '{EmbeddedResourceName}' not found.");
        return await LoadAsync(stream, cancellationToken);
    }

    public async Task<IReadOnlyList<Station>> LoadAsync(Stream json, CancellationToken cancellationToken = default)
    {
        var file = await JsonSerializer.DeserializeAsync<StationsFile>(json, JsonOptions, cancellationToken)
            ?? throw new InvalidDataException("stations.json is empty.");
        return file.Stations.Where(s => s.Streams.Count > 0).ToList();
    }

    private sealed record StationsFile
    {
        public int Version { get; init; }
        public IReadOnlyList<Station> Stations { get; init; } = [];
    }
}
