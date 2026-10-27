using AntenimYok.Core.Playback;
using AntenimYok.Core.Stations;
using Microsoft.Extensions.Logging.Abstractions;

namespace AntenimYok.Tests;

public class RadioPlayerTests
{
    private static Station MakeStation(params string[] urls) => new()
    {
        Id = "test",
        Name = "Test FM",
        Streams = urls.Select(u => new StationStream { Url = u }).ToList(),
    };

    private static RadioPlayer MakePlayer(FakeStreamPlayer fake, TimeSpan? timeout = null) =>
        new(fake, new PassThroughResolver(), NullLogger<RadioPlayer>.Instance)
        {
            OpenTimeout = timeout ?? TimeSpan.FromSeconds(5),
        };

    [Fact]
    public async Task Play_FirstStreamWorks_Plays()
    {
        var fake = new FakeStreamPlayer();
        var player = MakePlayer(fake);
        var states = new List<PlaybackState>();
        player.StateChanged += (_, _) => states.Add(player.State);

        await player.PlayAsync(MakeStation("https://a/1", "https://a/2"));

        Assert.Equal(PlaybackState.Playing, player.State);
        Assert.Equal("https://a/1", player.CurrentStream?.Url);
        Assert.Equal([PlaybackState.Connecting, PlaybackState.Playing], states);
        Assert.Equal(["https://a/1"], fake.Opened);
    }

    [Fact]
    public async Task Play_FirstStreamFails_FallsBackToNext()
    {
        var fake = new FakeStreamPlayer { Failing = { "https://a/1" } };
        var player = MakePlayer(fake);

        await player.PlayAsync(MakeStation("https://a/1", "https://a/2"));

        Assert.Equal(PlaybackState.Playing, player.State);
        Assert.Equal("https://a/2", player.CurrentStream?.Url);
        Assert.Equal(["https://a/1", "https://a/2"], fake.Opened);
    }

    [Fact]
    public async Task Play_FirstStreamHangs_TimesOutAndFallsBack()
    {
        var fake = new FakeStreamPlayer { Hanging = { "https://a/1" } };
        var player = MakePlayer(fake, TimeSpan.FromMilliseconds(100));

        await player.PlayAsync(MakeStation("https://a/1", "https://a/2"));

        Assert.Equal(PlaybackState.Playing, player.State);
        Assert.Equal("https://a/2", player.CurrentStream?.Url);
    }

    [Fact]
    public async Task Play_AllStreamsFail_ReportsError()
    {
        var fake = new FakeStreamPlayer { Failing = { "https://a/1", "https://a/2" } };
        var player = MakePlayer(fake);

        await player.PlayAsync(MakeStation("https://a/1", "https://a/2"));

        Assert.Equal(PlaybackState.Error, player.State);
        Assert.Equal("Test FM", player.CurrentStation?.Name);
        Assert.True(fake.StopCount > 0);
    }

    [Fact]
    public async Task Play_SupersededByAnotherStation_FirstCallDoesNotOverwriteState()
    {
        var fake = new FakeStreamPlayer { Hanging = { "https://a/1" } };
        var player = MakePlayer(fake);

        var first = player.PlayAsync(MakeStation("https://a/1"));
        var second = new Station { Id = "b", Name = "B FM", Streams = [new StationStream { Url = "https://b/1" }] };
        await player.PlayAsync(second);
        await first;

        Assert.Equal(PlaybackState.Playing, player.State);
        Assert.Equal("B FM", player.CurrentStation?.Name);
    }

    [Fact]
    public async Task Stop_WhileConnecting_EndsStopped()
    {
        var fake = new FakeStreamPlayer { Hanging = { "https://a/1" } };
        var player = MakePlayer(fake);

        var play = player.PlayAsync(MakeStation("https://a/1", "https://a/2"));
        player.Stop();
        await play;

        Assert.Equal(PlaybackState.Stopped, player.State);
        Assert.Equal(["https://a/1"], fake.Opened);
    }

    [Fact]
    public async Task PlaybackFailed_WhilePlaying_ReportsError()
    {
        var fake = new FakeStreamPlayer();
        var player = MakePlayer(fake);
        await player.PlayAsync(MakeStation("https://a/1"));

        fake.RaiseFailed();

        Assert.Equal(PlaybackState.Error, player.State);
    }

    [Fact]
    public void Volume_IsClamped()
    {
        var fake = new FakeStreamPlayer();
        var player = MakePlayer(fake);

        player.Volume = 1.5;
        Assert.Equal(1, fake.Volume);
        player.Volume = -1;
        Assert.Equal(0, fake.Volume);
    }

    private sealed class PassThroughResolver : IStreamResolver
    {
        public Task<Uri> ResolveAsync(StationStream stream, CancellationToken cancellationToken) =>
            Task.FromResult(new Uri(stream.Url));
    }

    private sealed class FakeStreamPlayer : IStreamPlayer
    {
        public HashSet<string> Failing { get; } = [];
        public HashSet<string> Hanging { get; } = [];
        public List<string> Opened { get; } = [];
        public int StopCount { get; private set; }
        public double Volume { get; set; }
        public bool IsMuted { get; set; }

        public event EventHandler? PlaybackFailed;

        public async Task OpenAsync(Uri uri, StreamType type, CancellationToken cancellationToken)
        {
            var url = uri.OriginalString;
            Opened.Add(url);
            if (Hanging.Contains(url))
                await Task.Delay(Timeout.Infinite, cancellationToken);
            if (Failing.Contains(url))
                throw new IOException("boom");
        }

        public void Stop() => StopCount++;

        public void RaiseFailed() => PlaybackFailed?.Invoke(this, EventArgs.Empty);
    }
}
