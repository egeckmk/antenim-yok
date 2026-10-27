using AntenimYok.Core.Stations;
using Microsoft.Extensions.Logging.Abstractions;

namespace AntenimYok.Tests;

public sealed class FavoritesStoreTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "AntenimYokTests", Guid.NewGuid().ToString("N"));

    private static Station S(string id) =>
        new() { Id = id, Name = id.ToUpperInvariant(), Streams = [new StationStream { Url = "https://x/live" }] };

    private FavoritesStore Favorites() => new(Path.Combine(_dir, "favorites.json"), NullLogger<FavoritesStore>.Instance);

    [Fact]
    public void FirstRun_HasNoFavorites()
    {
        Assert.Empty(Favorites().Load());
    }

    [Fact]
    public void AddedStations_SurviveRestart_InOrder_WithTheirData()
    {
        var store = Favorites();
        store.Load();
        store.Add(S("rb-2") with { Logo = "https://x/logo.png" });
        store.Add(S("rb-1"));

        var result = Favorites().Load();

        Assert.Equal(["rb-2", "rb-1"], result.Select(s => s.Id));
        Assert.Equal("https://x/logo.png", result[0].Logo);
        Assert.Equal("https://x/live", result[0].Streams[0].Url);
    }

    [Fact]
    public void Removed_StaysRemoved()
    {
        var store = Favorites();
        store.Load();
        store.Add(S("rb-1"));
        store.Add(S("rb-2"));
        store.Remove("rb-1");

        Assert.Equal(["rb-2"], Favorites().Load().Select(s => s.Id));
    }

    [Fact]
    public void Add_IsIdempotent_AndIsFavoriteReflectsIt()
    {
        var store = Favorites();
        store.Load();
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
            """{ "stations": [ { "id": "a", "name": "A", "streams": [ { "url": "https://x/a", "unverified": true } ] } ], "knownCatalogIds": [ "a" ] }""");

        Assert.Equal(["a"], Favorites().Load().Select(s => s.Id));
    }

    [Fact]
    public void CorruptFile_StartsEmpty()
    {
        Directory.CreateDirectory(_dir);
        File.WriteAllText(Path.Combine(_dir, "favorites.json"), "{ not json");

        Assert.Empty(Favorites().Load());
    }

    public void Dispose()
    {
        if (Directory.Exists(_dir))
            Directory.Delete(_dir, recursive: true);
    }
}
