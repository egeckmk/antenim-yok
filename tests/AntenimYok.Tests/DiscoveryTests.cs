using System.Net;
using System.Text;
using AntenimYok.Core.Discovery;
using AntenimYok.Core.Stations;

namespace AntenimYok.Tests;

public class DiscoveryTests
{
    [Fact]
    public async Task GetByCountry_MapsStationsAndSkipsInvalid()
    {
        const string json = """
            [
              { "stationuuid": "u1", "name": " Radyo A ", "url": "http://a/x.pls", "url_resolved": "http://a/live",
                "favicon": "https://a/logo.png", "tags": "pop,turkish pop,Pop", "codec": "MP3", "bitrate": 128, "hls": 0, "votes": 10 },
              { "stationuuid": "u2", "name": "Radyo B", "url": "https://b/playlist.m3u8", "url_resolved": "",
                "favicon": "", "tags": "", "codec": "UNKNOWN", "bitrate": 0, "hls": 1, "votes": 3 },
              { "stationuuid": "u3", "name": "Broken", "url": "not a url", "url_resolved": "" },
              { "stationuuid": "", "name": "No id", "url": "http://c/live" }
            ]
            """;
        var client = new RadioBrowserClient(new HttpClient(new JsonHandler(json)));

        var result = await client.GetByCountryAsync("TR");

        Assert.Equal(2, result.Count);
        var a = result[0];
        Assert.Equal("rb-u1", a.Station.Id);
        Assert.Equal("Radyo A", a.Station.Name);
        Assert.Equal("u1", a.Station.RadioBrowserUuid);
        Assert.Equal("https://a/logo.png", a.Station.Logo);
        Assert.Equal("http://a/live", a.Station.Streams[0].Url);
        Assert.Equal(StreamType.Icecast, a.Station.Streams[0].Type);
        Assert.Equal(128, a.Station.Streams[0].Bitrate);
        Assert.Equal(["pop", "turkish pop"], a.Tags);

        var b = result[1];
        Assert.Null(b.Station.Logo);
        Assert.Equal(StreamType.Hls, b.Station.Streams[0].Type);
        Assert.Equal("https://b/playlist.m3u8", b.Station.Streams[0].Url);
        Assert.Null(b.Station.Streams[0].Codec);
        Assert.Null(b.Station.Streams[0].Bitrate);
    }

    [Theory]
    [InlineData("Pop", "turkish pop", true)]
    [InlineData("Türkü / Halk", "Türkü", true)]
    [InlineData("Türkü / Halk", "turku", true)]
    [InlineData("Nostalji", "80s", true)]
    [InlineData("Haber / Konuşma", "news", true)]
    [InlineData("Rock", "pop", false)]
    [InlineData("Tümü", "anything", true)]
    public void Genre_MatchesTags(string genreName, string tag, bool expected)
    {
        var genre = Genre.Defaults.Single(g => g.Name == genreName);
        var station = new DiscoveredStation(new Station { Id = "x", Name = "X" }, [tag], 0);
        Assert.Equal(expected, genre.Matches(station));
    }

    [Fact]
    public void Genre_AllMatchesStationWithoutTags()
    {
        var station = new DiscoveredStation(new Station { Id = "x", Name = "X" }, [], 0);
        Assert.True(Genre.All.Matches(station));
        Assert.False(Genre.Defaults[1].Matches(station));
    }

    private sealed class JsonHandler(string json) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) =>
            Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(json, Encoding.UTF8, "application/json"),
            });
    }
}
