using AntenimYok.Core.Stations;
using Microsoft.Extensions.Logging;

namespace AntenimYok.Core.Playback;

public enum PlaybackState
{
    Stopped,
    Connecting,
    Playing,
    Error,
}

/// <summary>
/// Plays a station by trying its streams in priority order, falling back to the next one
/// when a stream fails or does not open within <see cref="OpenTimeout"/>.
/// </summary>
public sealed class RadioPlayer
{
    public static readonly TimeSpan DefaultOpenTimeout = TimeSpan.FromSeconds(10);

    private readonly IStreamPlayer _player;
    private readonly IStreamResolver _resolver;
    private readonly ILogger<RadioPlayer> _logger;
    private readonly Lock _gate = new();
    private CancellationTokenSource? _playCts;

    public RadioPlayer(IStreamPlayer player, IStreamResolver resolver, ILogger<RadioPlayer> logger)
    {
        _player = player;
        _resolver = resolver;
        _logger = logger;
        _player.PlaybackFailed += OnPlaybackFailed;
    }

    public TimeSpan OpenTimeout { get; init; } = DefaultOpenTimeout;

    public Station? CurrentStation { get; private set; }
    public StationStream? CurrentStream { get; private set; }
    public PlaybackState State { get; private set; }

    /// <summary>May be raised on a background thread.</summary>
    public event EventHandler? StateChanged;

    /// <summary>0.0 – 1.0</summary>
    public double Volume
    {
        get => _player.Volume;
        set => _player.Volume = Math.Clamp(value, 0, 1);
    }

    public bool IsMuted
    {
        get => _player.IsMuted;
        set => _player.IsMuted = value;
    }

    public async Task PlayAsync(Station station)
    {
        var token = ReplacePlayToken(new CancellationTokenSource());
        SetState(station, null, PlaybackState.Connecting);

        foreach (var stream in station.Streams)
        {
            using var attemptCts = CancellationTokenSource.CreateLinkedTokenSource(token);
            attemptCts.CancelAfter(OpenTimeout);
            try
            {
                var uri = await _resolver.ResolveAsync(stream, attemptCts.Token);
                await _player.OpenAsync(uri, stream.Type, attemptCts.Token);
                if (token.IsCancellationRequested)
                    return;

                _logger.LogInformation("Playing {Station} from {Url}", station.Name, uri);
                SetState(station, stream, PlaybackState.Playing);
                return;
            }
            catch (OperationCanceledException) when (token.IsCancellationRequested)
            {
                return; // Superseded by another PlayAsync or Stop.
            }
            catch (OperationCanceledException)
            {
                _logger.LogWarning("Stream timed out after {Timeout}: {Url}", OpenTimeout, stream.Url);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Stream failed: {Url}", stream.Url);
            }
        }

        if (token.IsCancellationRequested)
            return;

        _player.Stop();
        SetState(station, null, PlaybackState.Error);
    }

    public void Stop()
    {
        ReplacePlayToken(null);
        _player.Stop();
        SetState(CurrentStation, null, PlaybackState.Stopped);
    }

    private CancellationToken ReplacePlayToken(CancellationTokenSource? next)
    {
        lock (_gate)
        {
            // Not disposed: an in-flight PlayAsync still checks its token.
            _playCts?.Cancel();
            _playCts = next;
            return next?.Token ?? CancellationToken.None;
        }
    }

    private void OnPlaybackFailed(object? sender, EventArgs e)
    {
        if (State != PlaybackState.Playing)
            return;

        _logger.LogWarning("Playback of {Station} stopped unexpectedly", CurrentStation?.Name);
        ReplacePlayToken(null);
        SetState(CurrentStation, null, PlaybackState.Error);
    }

    private void SetState(Station? station, StationStream? stream, PlaybackState state)
    {
        CurrentStation = station;
        CurrentStream = stream;
        State = state;
        StateChanged?.Invoke(this, EventArgs.Empty);
    }
}
