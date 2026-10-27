using AntenimYok.Core.Stations;
using Microsoft.Extensions.Logging.Abstractions;

namespace AntenimYok.Tests;

public sealed class FavoritesStoreTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "AntenimYokTests", Guid.NewGuid().ToString("N"));

    private static Station S(string id, string? uuid = null, string url = "https://x/live") =>
        new() { Id = id, Name = id.ToUpperInvariant(), RadioBrowserUuid = uuid, Streams = [new StationStream { Url = url }] };

    private FavoritesStore Favorites() => new(Path.Combine(_dir, "favorites.json"), NullLogger<FavoritesStore>.Instance);

    [Fact]
    public void FirstRun_HasNoFavorites_EvenWithACatalog()
    {
        Assert.Empty(Favorites().Load([S("a"), S("b")]));
    }

    [Fact]
    public void AddedStations_SurviveRestart_InOrder()
    {
        var store = Favorites();
        store.Load([]);
        store.Add(S("rb-2", uuid: "2"));
        store.Add(S("rb-1", uuid: "1"));

        var result = Favorites().Load([]);

        Assert.Equal(["rb-2", "rb-1"], result.Select(s => s.Id));
    }

    [Fact]
    public void Removed_StaysRemoved()
    {
        var store = Favorites();
        store.Load([]);
        store.Add(S("rb-1"));
        store.Add(S("rb-2"));
        store.Remove("rb-1");

        Assert.Equal(["rb-2"], Favorites().Load([]).Select(s => s.Id));
    }

    [Fact]
    public void CatalogFavorite_GetsCurrentCatalogData()
    {
        var store = Favorites();
        store.Load([]);
        store.Add(S("a", url: "https://old/a"));

        var result = Favorites().Load([S("a", url: "https://new/a")]);

        Assert.Equal("https://new/a", Assert.Single(result).Streams[0].Url);
    }

    [Fact]
    public void RadioBrowserFavorite_MatchingCatalogEntry_UsesCatalogEntry()
    {
        var store = Favorites();
        store.Load([]);
        store.Add(S("rb-9", uuid: "9"));

        var result = Favorites().Load([S("nine", uuid: "9")]);

        Assert.Equal("nine", Assert.Single(result).Id);
    }

    [Fact]
    public void Add_IsIdempotent_AndIsFavoriteReflectsIt()
    {
        var store = Favorites();
        store.Load([]);
        store.Add(S("rb-1"));
        store.Add(S("rb-1"));

        Assert.Single(store.Favorites);
        Assert.True(store.IsFavorite("rb-1"));
        store.Remove("rb-1");
        Assert.False(store.IsFavorite("rb-1"));
    }

    [Fact]
    public void OldFileWithExtraFields_StillLoads()
    {
        Directory.CreateDirectory(_dir);
        File.WriteAllText(Path.Combine(_dir, "favorites.json"),
            """{ "stations": [ { "id": "a", "name": "A", "streams": [ { "url": "https://x/a" } ] } ], "knownCatalogIds": [ "a" ] }""");

        Assert.Equal(["a"], Favorites().Load([]).Select(s => s.Id));
    }

    public void Dispose()
    {
        if (Directory.Exists(_dir))
            Directory.Delete(_dir, recursive: true);
    }
}
