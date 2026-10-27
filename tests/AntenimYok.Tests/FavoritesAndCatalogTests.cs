using System.Net;
using System.Text;
using AntenimYok.Core.Stations;
using Microsoft.Extensions.Logging.Abstractions;

namespace AntenimYok.Tests;

public sealed class FavoritesAndCatalogTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "AntenimYokTests", Guid.NewGuid().ToString("N"));

    private static Station S(string id, string? uuid = null, string url = "https://x/live") =>
        new() { Id = id, Name = id.ToUpperInvariant(), RadioBrowserUuid = uuid, Streams = [new StationStream { Url = url }] };

    private FavoritesStore Favorites() => new(Path.Combine(_dir, "favorites.json"), NullLogger<FavoritesStore>.Instance);

    [Fact]
    public void FirstRun_FavoritesAreTheCatalog()
    {
        var result = Favorites().Merge([S("a"), S("b")]);
        Assert.Equal(["a", "b"], result.Select(s => s.Id));
    }

    [Fact]
    public void RemovedCatalogStation_StaysRemoved_NewOneIsAppended()
    {
        Favorites().Merge([S("a"), S("b")]);
        var store = Favorites();
        store.Merge([S("a"), S("b")]);
        store.Remove("a");

        var result = Favorites().Merge([S("a"), S("b"), S("c")]);

        Assert.Equal(["b", "c"], result.Select(s => s.Id));
    }

    [Fact]
    public void AddedRadioBrowserStation_SurvivesRestart_AndCatalogUrlsAreRefreshed()
    {
        var store = Favorites();
        store.Merge([S("a", url: "https://old/a")]);
        store.Add(S("rb-1", uuid: "1"));

        var result = Favorites().Merge([S("a", url: "https://new/a")]);

        Assert.Equal(["a", "rb-1"], result.Select(s => s.Id));
        Assert.Equal("https://new/a", result[0].Streams[0].Url);
    }

    [Fact]
    public void RadioBrowserFavorite_LaterInCatalog_UsesCatalogEntry()
    {
        var store = Favorites();
        store.Merge([S("a")]);
        store.Add(S("rb-9", uuid: "9"));

        var result = Favorites().Merge([S("a"), S("nine", uuid: "9")]);

        Assert.Equal(["a", "nine"], result.Select(s => s.Id));
    }

    [Fact]
    public void Add_IsIdempotent_AndIsFavoriteReflectsIt()
    {
        var store = Favorites();
        store.Merge([]);
        store.Add(S("rb-1"));
        store.Add(S("rb-1"));

        Assert.Single(store.Favorites);
        Assert.True(store.IsFavorite("rb-1"));
        store.Remove("rb-1");
        Assert.False(store.IsFavorite("rb-1"));
    }

    [Fact]
    public async Task Catalog_WithoutDownload_UsesEmbeddedList()
    {
        var catalog = MakeCatalog(new FakeServer(), remote: null);
        var stations = await catalog.LoadAsync();
        Assert.Contains(stations, s => s.Id == "kafa-radyo");
    }

    [Fact]
    public async Task Catalog_Refresh_SavesValidList_UsedOnNextLoad()
    {
        var server = new FakeServer { Body = StationsJson("remote-only") , ETag = "\"v1\"" };
        var catalog = MakeCatalog(server);

        Assert.True(await catalog.RefreshAsync());
        var stations = await catalog.LoadAsync();

        Assert.Equal(["remote-only"], stations.Select(s => s.Id));
    }

    [Fact]
    public async Task Catalog_Refresh_SendsETag_AndHandlesNotModified()
    {
        var server = new FakeServer { Body = StationsJson("r"), ETag = "\"v1\"" };
        var catalog = MakeCatalog(server);
        await catalog.RefreshAsync();

        server.Status = HttpStatusCode.NotModified;
        Assert.False(await catalog.RefreshAsync());
        Assert.Equal("\"v1\"", server.LastIfNoneMatch);
    }

    [Fact]
    public async Task Catalog_Refresh_RejectsBrokenList()
    {
        var server = new FakeServer { Body = StationsJson("good") };
        var catalog = MakeCatalog(server);
        await catalog.RefreshAsync();

        server.Body = "{ \"stations\": [] }";
        Assert.False(await catalog.RefreshAsync());
        server.Body = "not json";
        Assert.False(await catalog.RefreshAsync());

        Assert.Equal(["good"], (await catalog.LoadAsync()).Select(s => s.Id));
    }

    private StationCatalog MakeCatalog(FakeServer server, string? remote = "https://gist.example/stations.json") =>
        new(new StationRepository(), new HttpClient(server), remote is null ? null : new Uri(remote),
            Path.Combine(_dir, "stations.json"), NullLogger<StationCatalog>.Instance);

    private static string StationsJson(string id) =>
        $$"""{ "version": 1, "stations": [ { "id": "{{id}}", "name": "N", "streams": [ { "url": "https://x/live", "type": "icecast" } ] } ] }""";

    private sealed class FakeServer : HttpMessageHandler
    {
        public string Body { get; set; } = "";
        public string? ETag { get; set; }
        public HttpStatusCode Status { get; set; } = HttpStatusCode.OK;
        public string? LastIfNoneMatch { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            LastIfNoneMatch = request.Headers.IfNoneMatch.FirstOrDefault()?.ToString();
            var response = new HttpResponseMessage(Status) { Content = new StringContent(Body, Encoding.UTF8) };
            if (ETag is not null)
                response.Headers.ETag = System.Net.Http.Headers.EntityTagHeaderValue.Parse(ETag);
            return Task.FromResult(response);
        }
    }

    public void Dispose()
    {
        if (Directory.Exists(_dir))
            Directory.Delete(_dir, recursive: true);
    }
}
