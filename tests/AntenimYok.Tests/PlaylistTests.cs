using System.Net;
using AntenimYok.Core.Playback;
using AntenimYok.Core.Stations;
using Microsoft.Extensions.Logging.Abstractions;

namespace AntenimYok.Tests;

public class PlaylistTests
{
    private static readonly Uri Base = new("https://radio.example/lists/live.pls");

    [Theory]
    [InlineData("https://x/live.pls", PlaylistFormat.Pls)]
    [InlineData("https://x/LIVE.M3U?token=1", PlaylistFormat.M3u)]
    [InlineData("https://x/playlist.m3u8", null)]
    [InlineData("https://x/stream", null)]
    public void DetectFormat_UsesExtension(string url, PlaylistFormat? expected)
    {
        Assert.Equal(expected, PlaylistParser.DetectFormat(new Uri(url)));
    }

    [Fact]
    public void Parse_Pls_ReturnsFileEntriesInOrder()
    {
        const string pls = "[playlist]\r\nNumberOfEntries=2\r\nFile1=http://a.example:8000/stream\r\nTitle1=Main\r\nFile2=https://b.example/stream\r\nVersion=2\r\n";

        var urls = PlaylistParser.Parse(pls, PlaylistFormat.Pls, Base);

        Assert.Equal([new Uri("http://a.example:8000/stream"), new Uri("https://b.example/stream")], urls);
    }

    [Fact]
    public void Parse_M3u_SkipsCommentsAndResolvesRelative()
    {
        const string m3u = "#EXTM3U\n#EXTINF:-1,Radio\nhttps://a.example/live\n\nbackup/live\n";

        var urls = PlaylistParser.Parse(m3u, PlaylistFormat.M3u, Base);

        Assert.Equal([new Uri("https://a.example/live"), new Uri("https://radio.example/lists/backup/live")], urls);
    }

    [Fact]
    public void Parse_IgnoresNonHttpEntries()
    {
        var urls = PlaylistParser.Parse("file:///C:/x.mp3\nftp://x/y\n", PlaylistFormat.M3u, Base);
        Assert.Empty(urls);
    }

    [Fact]
    public async Task Resolver_ExpandsPlaylist()
    {
        var http = new HttpClient(new StubHandler("[playlist]\nFile1=https://real.example/stream\n"));
        var resolver = new StreamResolver(http, NullLogger<StreamResolver>.Instance);

        var uri = await resolver.ResolveAsync(new StationStream { Url = "https://radio.example/live.pls" }, CancellationToken.None);

        Assert.Equal(new Uri("https://real.example/stream"), uri);
    }

    [Theory]
    [InlineData("https://radio.example/stream", StreamType.Icecast)]
    [InlineData("https://radio.example/playlist.m3u8", StreamType.Hls)]
    public async Task Resolver_PassesThroughDirectStreams(string url, StreamType type)
    {
        var handler = new StubHandler("");
        var resolver = new StreamResolver(new HttpClient(handler), NullLogger<StreamResolver>.Instance);

        var uri = await resolver.ResolveAsync(new StationStream { Url = url, Type = type }, CancellationToken.None);

        Assert.Equal(new Uri(url), uri);
        Assert.Equal(0, handler.Calls);
    }

    private sealed class StubHandler(string body) : HttpMessageHandler
    {
        public int Calls { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(body),
                RequestMessage = request,
            });
        }
    }
}
