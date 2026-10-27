using System.Text;
using AntenimYok.Core.Stations;

namespace AntenimYok.Tests;

public class StationRepositoryTests
{
    [Fact]
    public async Task LoadEmbedded_ReturnsStationsWithStreams()
    {
        var stations = await new StationRepository().LoadEmbeddedAsync();

        Assert.NotEmpty(stations);
        Assert.All(stations, s =>
        {
            Assert.False(string.IsNullOrWhiteSpace(s.Id));
            Assert.False(string.IsNullOrWhiteSpace(s.Name));
            Assert.NotEmpty(s.Streams);
            Assert.All(s.Streams, st => Assert.True(Uri.TryCreate(st.Url, UriKind.Absolute, out _), st.Url));
        });
        Assert.Equal(stations.Count, stations.Select(s => s.Id).Distinct().Count());
    }

    [Fact]
    public async Task Load_ParsesAllFields()
    {
        const string json = """
            {
              "version": 1,
              "stations": [
                {
                  "id": "x", "name": "Test FM", "logo": null, "logoOnDarkOnly": true,
                  "radioBrowserUuid": "abc",
                  "streams": [
                    { "url": "https://a/live.m3u8", "type": "hls", "codec": "AAC", "bitrate": 128 },
                    { "url": "https://b/live", "type": "icecast", "unverified": true }
                  ]
                },
                { "id": "empty", "name": "No Streams", "streams": [] }
              ]
            }
            """;

        var stations = await new StationRepository().LoadAsync(new MemoryStream(Encoding.UTF8.GetBytes(json)));

        var station = Assert.Single(stations);
        Assert.True(station.LogoOnDarkOnly);
        Assert.Null(station.Logo);
        Assert.Equal("abc", station.RadioBrowserUuid);
        Assert.Equal(StreamType.Hls, station.Streams[0].Type);
        Assert.Equal(128, station.Streams[0].Bitrate);
        Assert.Equal(StreamType.Icecast, station.Streams[1].Type);
        Assert.True(station.Streams[1].Unverified);
        Assert.Null(station.Streams[1].Bitrate);
    }

    [Theory]
    [InlineData("Kafa Radyo", "KR")]
    [InlineData("Virgin Radio Türkiye", "VR")]
    [InlineData("Metro FM", "MF")]
    [InlineData("idil", "İ")]
    public void Initials_UsesFirstTwoWords(string name, string expected)
    {
        var station = new Station { Id = "x", Name = name };
        Assert.Equal(expected, station.Initials);
    }
}
