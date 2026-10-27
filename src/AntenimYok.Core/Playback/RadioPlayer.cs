using AntenimYok.Core.Stations;
using Microsoft.Extensions.Logging;

namespace AntenimYok.Core.Playback;

public enum PlaybackState
{
    Stopped,
    Connecting,
    Playing,

    /// <summary>A playing stream dropped; waiting to retry.</summary>
    Reconnecting,
    Error,
}

/// <summary>
/// Plays a station by trying its streams in priority order, falling back to the next one
/// when a stream fails or does not open within <see cref="OpenTimeout"/>.
/// If a playing stream drops, it keeps reconnecting with backoff (see <see cref="ReconnectDelays"/>).
/// </summary>
public sealed class RadioPlayer
{
    public static readonly TimeSpan DefaultOpenTimeout = TimeSpan.FromSeconds(10);

    // ~5 minutes in total before giving up.
    public static readonly IReadOnlyList<TimeSpan> DefaultReconnectDelays =
    [
        TimeSpan.FromSeconds(1), TimeSpan.FromSeconds(2), TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(10),
        TimeSpan.FromSeconds(20), TimeSpan.FromSeconds(30), TimeSpan.FromSeconds(30), TimeSpan.FromSeconds(30),
        TimeSpan.FromSeconds(30), TimeSpan.FromSeconds(30), TimeSpan.FromSeconds(30), TimeSpan.FromSeconds(30),
    ];

    private readonly IStreamPlayer _player;
    private readonly IStreamResolver _resolver;
    private readonly ILogger<RadioPlayer> _logger;
    private readonly Lock _gate = new();
    private CancellationTokenSource? _playCts;
    private TaskCompletionSource _networkAvailable = NewSignal();

    public RadioPlayer(IStreamPlayer player, IStreamResolver resolver, ILogger<RadioPlayer> logger)
    {
        _player = player;
        _resolver = resolver;
        _logger = logger;
        _player.PlaybackFailed += OnPlaybackFailed;
    }

    public TimeSpan OpenTimeout { get; init; } = DefaultOpenTimeout;

    /// <summary>Wait before each reconnect attempt; after the last one the player gives up with <see cref="PlaybackState.Error"/>.</summary>
    public IReadOnlyList<TimeSpan> ReconnectDelays { get; init; } = DefaultReconnectDelays;

    public Station? CurrentStation { get; private set; }
    public StationStream? CurrentStream { get; private set; }
    public PlaybackState State { get; private set; }

    /// <summary>Connecting, playing or reconnecting — i.e. "stop" is the meaningful action.</summary>
    public bool IsActive => State is PlaybackState.Connecting or PlaybackState.Playing or PlaybackState.Reconnecting;

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

        if (await TryStreamsAsync(station, token) || token.IsCancellationRequested)
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

    /// <summary>Call when the network comes back: a pending reconnect retries right away.</summary>
    public void NotifyNetworkAvailable() => Interlocked.Exchange(ref _networkAvailable, NewSignal()).TrySetResult();

    /// <summary>Tries each stream in order; on success sets <see cref="PlaybackState.Playing"/> and returns true.</summary>
    private async Task<bool> TryStreamsAsync(Station station, CancellationToken token)
    {
        foreach (var stream in station.Streams)
        {
            using var attemptCts = CancellationTokenSource.CreateLinkedTokenSource(token);
            attemptCts.CancelAfter(OpenTimeout);
            try
            {
                var uri = await _resolver.ResolveAsync(stream, attemptCts.Token);
                await _player.OpenAsync(uri, stream.Type, attemptCts.Token);
                if (token.IsCancellationRequested)
                    return false;

                _logger.LogInformation("Playing {Station} from {Url}", station.Name, uri);
                SetState(station, stream, PlaybackState.Playing);
                return true;
            }
            catch (OperationCanceledException) when (token.IsCancellationRequested)
            {
                return false; // Superseded by another PlayAsync or Stop.
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
        return false;
    }

    private async Task ReconnectAsync(Station station, CancellationToken token)
    {
        try
        {
            for (var attempt = 0; attempt < ReconnectDelays.Count; attempt++)
            {
                SetState(station, null, PlaybackState.Reconnecting);
                var networkAvailable = _networkAvailable.Task;
                await Task.WhenAny(Task.Delay(ReconnectDelays[attempt], token), networkAvailable);
                token.ThrowIfCancellationRequested();

                _logger.LogInformation("Reconnecting to {Station} (attempt {Attempt})", station.Name, attempt + 1);
                if (await TryStreamsAsync(station, token))
                    return;
                token.ThrowIfCancellationRequested();
            }

            _logger.LogWarning("Giving up reconnecting to {Station}", station.Name);
            _player.Stop();
            SetState(station, null, PlaybackState.Error);
        }
        catch (OperationCanceledException)
        {
            // Stopped or another station started.
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Reconnect loop failed");
            SetState(station, null, PlaybackState.Error);
        }
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
        if (State != PlaybackState.Playing || CurrentStation is not { } station)
            return;

        _logger.LogWarning("Playback of {Station} dropped; reconnecting", station.Name);
        var token = ReplacePlayToken(new CancellationTokenSource());
        _ = ReconnectAsync(station, token);
    }

    private void SetState(Station? station, StationStream? stream, PlaybackState state)
    {
        CurrentStation = station;
        CurrentStream = stream;
        State = state;
        StateChanged?.Invoke(this, EventArgs.Empty);
    }

    private static TaskCompletionSource NewSignal() => new(TaskCreationOptions.RunContinuationsAsynchronously);
}
