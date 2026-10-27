using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;

namespace AntenimYok.Core.Stations;

/// <summary>
/// The user's favorites (order matters: Ctrl+1…9, next/previous), kept locally in favorites.json.
/// Starts empty. Each favorite is stored as a full snapshot so stations found on Radio Browser survive restarts;
/// favorites that are also in the built-in catalog (stations.json) get the catalog's verified data on <see cref="Load"/>.
/// </summary>
public sealed class FavoritesStore(string path, ILogger<FavoritesStore> logger)
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        WriteIndented = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };

    private readonly Lock _gate = new();
    private List<Station> _favorites = [];

    /// <summary>%LOCALAPPDATA%\AntenimYok\favorites.json</summary>
    public static string DefaultPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AntenimYok", "favorites.json");

    public IReadOnlyList<Station> Favorites
    {
        get
        {
            lock (_gate)
                return _favorites.ToList();
        }
    }

    /// <summary>
    /// Loads favorites (empty on first run). Favorites that are catalog stations — same id, or a
    /// Radio Browser station with the catalog entry's Radio Browser id — get the catalog's current data.
    /// </summary>
    public IReadOnlyList<Station> Load(IReadOnlyList<Station> catalog)
    {
        lock (_gate)
        {
            _favorites = ReadFile()?.Stations.ToList() ?? [];

            var byId = catalog.ToDictionary(s => s.Id);
            var byUuid = catalog
                .Where(s => s.RadioBrowserUuid is not null)
                .GroupBy(s => s.RadioBrowserUuid!)
                .ToDictionary(g => g.Key, g => g.First());

            // Radio Browser favorite that is now in the catalog → use the catalog entry.
            _favorites = _favorites
                .Select(f => byId.GetValueOrDefault(f.Id)
                    ?? (f.RadioBrowserUuid is { } uuid ? byUuid.GetValueOrDefault(uuid) : null)
                    ?? f)
                .DistinctBy(f => f.Id)
                .ToList();

            return _favorites.ToList();
        }
    }

    public bool IsFavorite(string stationId)
    {
        lock (_gate)
            return _favorites.Any(f => f.Id == stationId);
    }

    public void Add(Station station)
    {
        lock (_gate)
        {
            if (_favorites.Any(f => f.Id == station.Id))
                return;
            _favorites.Add(station);
            Save();
        }
    }

    public void Remove(string stationId)
    {
        lock (_gate)
        {
            if (_favorites.RemoveAll(f => f.Id == stationId) > 0)
                Save();
        }
    }

    private FavoritesFile? ReadFile()
    {
        try
        {
            if (File.Exists(path))
                return JsonSerializer.Deserialize<FavoritesFile>(File.ReadAllText(path), JsonOptions);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Could not read favorites from {Path}; starting empty", path);
        }
        return null;
    }

    private void Save()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            var temp = path + ".tmp";
            var file = new FavoritesFile { Stations = _favorites };
            File.WriteAllText(temp, JsonSerializer.Serialize(file, JsonOptions));
            File.Move(temp, path, overwrite: true);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Could not save favorites to {Path}", path);
        }
    }

    private sealed record FavoritesFile
    {
        public IReadOnlyList<Station> Stations { get; init; } = [];
    }
}
