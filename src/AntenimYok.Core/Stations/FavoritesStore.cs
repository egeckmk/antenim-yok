using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;

namespace AntenimYok.Core.Stations;

/// <summary>
/// The user's favorites (order matters: Ctrl+1…9, next/previous), kept in favorites.json.
/// Each favorite is stored as a full snapshot so stations found on Radio Browser survive restarts;
/// catalog stations (stations.json) are refreshed from the catalog on every <see cref="Merge"/>.
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
    private HashSet<string> _knownCatalogIds = [];

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
    /// Loads favorites and reconciles them with the catalog: first run = the whole catalog;
    /// stations newly added to the catalog are appended once (removing one later sticks);
    /// catalog favorites get the catalog's current data (fresh stream URLs).
    /// </summary>
    public IReadOnlyList<Station> Merge(IReadOnlyList<Station> catalog)
    {
        lock (_gate)
        {
            var file = Load();
            _favorites = file?.Stations.ToList() ?? [];
            _knownCatalogIds = file?.KnownCatalogIds.ToHashSet() ?? [];

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

            foreach (var station in catalog)
            {
                if (_knownCatalogIds.Add(station.Id) && _favorites.All(f => f.Id != station.Id))
                    _favorites.Add(station);
            }

            Save();
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

    private FavoritesFile? Load()
    {
        try
        {
            if (File.Exists(path))
                return JsonSerializer.Deserialize<FavoritesFile>(File.ReadAllText(path), JsonOptions);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Could not read favorites from {Path}; starting from the catalog", path);
        }
        return null;
    }

    private void Save()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            var temp = path + ".tmp";
            var file = new FavoritesFile { Stations = _favorites, KnownCatalogIds = _knownCatalogIds.Order().ToList() };
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

        /// <summary>Catalog stations already offered once (so a removed one is not re-added).</summary>
        public IReadOnlyList<string> KnownCatalogIds { get; init; } = [];
    }
}
