using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;

namespace AntenimYok.Core.Stations;

/// <summary>
/// The user's favorites (order matters: Ctrl+1…9, next/previous), kept locally in favorites.json.
/// Starts empty. Each favorite is stored as a full snapshot (streams, logo), so it plays without any lookup.
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

    /// <summary>Loads favorites from disk (empty on first run).</summary>
    public IReadOnlyList<Station> Load()
    {
        lock (_gate)
        {
            _favorites = (ReadFile()?.Stations ?? []).DistinctBy(f => f.Id).ToList();
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
            AtomicFile.WriteAllText(path, JsonSerializer.Serialize(new FavoritesFile { Stations = _favorites }, JsonOptions));
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
