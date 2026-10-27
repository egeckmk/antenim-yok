using System.Net;
using System.Runtime.CompilerServices;
using System.Text;
using AntenimYok.Core.Playback;
using AntenimYok.Core.Stations;
using Microsoft.Extensions.Logging.Abstractions;

namespace AntenimYok.Tests;

public class SongTitleTests
{
    [Theory]
    [InlineData("StreamTitle='Tarkan - Şımarık';StreamUrl='';", "Tarkan - Şımarık")]
    [InlineData("StreamTitle='It''s fine';", "It''s fine")]
    [InlineData("StreamTitle='';", null)]
    [InlineData("StreamTitle=' - ';", null)]
    [InlineData("StreamUrl='x';", null)]
    public void ParseStreamTitle(string block, string? expected)
    {
        Assert.Equal(expected, IcyMetadataReader.ParseStreamTitle(Encoding.UTF8.GetBytes(block)));
    }

    [Fact]
    public void ParseStreamTitle_FallsBackToTurkishCodePage()
    {
        // "Şımarık" in Windows-1254 is not valid UTF-8.
        Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
        var bytes = Encoding.GetEncoding(1254).GetBytes("StreamTitle='Şımarık';");
        Assert.Equal("Şımarık", IcyMetadataReader.ParseStreamTitle(bytes));
    }

    [Fact]
    public async Task Reader_YieldsTitlesFromInterleavedStream_SkippingRepeats()
    {
        const int metaInt = 8;
        var body = new MemoryStream();
        foreach (var meta in new[] { "StreamTitle='A';", "", "StreamTitle='A';", "StreamTitle='B';" })
        {
            body.Write(new byte[metaInt]); // audio
            var bytes = Encoding.UTF8.GetBytes(meta);
            var blocks = (bytes.Length + 15) / 16;
            body.WriteByte((byte)blocks);
            body.Write(bytes);
            body.Write(new byte[blocks * 16 - bytes.Length]);
        }
        var handler = new IcyHandler(body.ToArray(), metaInt);
        var reader = new IcyMetadataReader(new HttpClient(handler));

        var titles = new List<string>();
        await foreach (var t in reader.ReadTitlesAsync(new Uri("https://radio/live"), CancellationToken.None))
            titles.Add(t);

        Assert.Equal(["A", "B"], titles);
        Assert.Equal("1", handler.IcyHeader);
    }

    [Fact]
    public async Task Reader_WithoutMetaInt_YieldsNothing()
    {
        var reader = new IcyMetadataReader(new HttpClient(new IcyHandler([1, 2, 3], metaInt: null)));
        var titles = new List<string>();
        await foreach (var t in reader.ReadTitlesAsync(new Uri("https://radio/live"), CancellationToken.None))
            titles.Add(t);
        Assert.Empty(titles);
    }

    [Fact]
    public async Task Monitor_ReadsOnlyWhileIcecastPlays()
    {
        var fakeReader = new ScriptedReader("Song 1");
        var (radio, fakePlayer) = MakeRadio();
        var monitor = new SongTitleMonitor(radio, fakeReader, NullLogger<SongTitleMonitor>.Instance);
        var changed = new SemaphoreSlim(0);
        monitor.TitleChanged += (_, _) => changed.Release();

        await radio.PlayAsync(Station("https://a/live", StreamType.Icecast));
        await WaitFor(() => monitor.CurrentTitle == "Song 1");
        Assert.Equal(new Uri("https://a/live"), fakeReader.LastUrl);

        radio.Stop();
        Assert.Null(monitor.CurrentTitle);

        await radio.PlayAsync(Station("https://b/playlist.m3u8", StreamType.Hls));
        Assert.Null(monitor.CurrentTitle);
        Assert.Equal(1, fakeReader.Calls);
    }

    [Fact]
    public async Task Monitor_Disabled_OpensNoConnection()
    {
        var fakeReader = new ScriptedReader("Song 1");
        var (radio, _) = MakeRadio();
        var monitor = new SongTitleMonitor(radio, fakeReader, NullLogger<SongTitleMonitor>.Instance) { IsEnabled = false };

        await radio.PlayAsync(Station("https://a/live", StreamType.Icecast));
        await Task.Delay(50);

        Assert.Equal(0, fakeReader.Calls);
        Assert.Null(monitor.CurrentTitle);
    }

    private static Station Station(string url, StreamType type) =>
        new() { Id = url, Name = "S", Streams = [new StationStream { Url = url, Type = type }] };

    private static (RadioPlayer, NullStreamPlayer) MakeRadio()
    {
        var player = new NullStreamPlayer();
        return (new RadioPlayer(player, new PassThroughResolver(), NullLogger<RadioPlayer>.Instance), player);
    }

    private static async Task WaitFor(Func<bool> condition)
    {
        for (var i = 0; i < 100 && !condition(); i++)
            await Task.Delay(20);
        Assert.True(condition());
    }

    private sealed class ScriptedReader(params string[] titles) : IIcyMetadataReader
    {
        public int Calls { get; private set; }
        public Uri? LastUrl { get; private set; }

        public async IAsyncEnumerable<string> ReadTitlesAsync(Uri streamUrl, [EnumeratorCancellation] CancellationToken cancellationToken)
        {
            Calls++;
            LastUrl = streamUrl;
            foreach (var t in titles)
            {
                await Task.Yield();
                yield return t;
            }
            await Task.Delay(Timeout.Infinite, cancellationToken);
        }
    }

    private sealed class PassThroughResolver : IStreamResolver
    {
        public Task<Uri> ResolveAsync(StationStream stream, CancellationToken cancellationToken) => Task.FromResult(new Uri(stream.Url));
    }

    private sealed class NullStreamPlayer : IStreamPlayer
    {
        public double Volume { get; set; }
        public bool IsMuted { get; set; }
        public event EventHandler? PlaybackFailed { add { } remove { } }
        public Task OpenAsync(Uri uri, StreamType type, CancellationToken cancellationToken) => Task.CompletedTask;
        public void Stop() { }
    }

    private sealed class IcyHandler(byte[] body, int? metaInt) : HttpMessageHandler
    {
        public string? IcyHeader { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            IcyHeader = request.Headers.TryGetValues("Icy-MetaData", out var v) ? v.First() : null;
            var response = new HttpResponseMessage(HttpStatusCode.OK) { Content = new ByteArrayContent(body) };
            if (metaInt is { } m)
                response.Headers.TryAddWithoutValidation("icy-metaint", m.ToString());
            return Task.FromResult(response);
        }
    }
}
