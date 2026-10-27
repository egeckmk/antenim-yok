using System;
using System.Threading;
using System.Threading.Tasks;
using AntenimYok.Core.Playback;
using AntenimYok.Core.Stations;
using Windows.Media;
using Windows.Media.Core;
using Windows.Media.Playback;
using Windows.Media.Streaming.Adaptive;

namespace AntenimYok.App.Services;

/// <summary><see cref="IStreamPlayer"/> on top of <see cref="MediaPlayer"/> (HLS via AdaptiveMediaSource).</summary>
public sealed class MediaPlayerStreamPlayer : IStreamPlayer, IDisposable
{
    // A live stream that buffers this long has effectively dropped (e.g. network gone without an error).
    private static readonly TimeSpan StallTimeout = TimeSpan.FromSeconds(15);

    private readonly MediaPlayer _player = new()
    {
        AutoPlay = false,
        AudioCategory = MediaPlayerAudioCategory.Media,
    };

    private readonly Timer _stallTimer;
    private TaskCompletionSource? _pendingOpen;
    private MediaSource? _source;

    public MediaPlayerStreamPlayer()
    {
        // Media keys are handled by MediaControlsService (radio: pause = stop, next = next station).
        _player.CommandManager.IsEnabled = false;
        _player.MediaOpened += OnMediaOpened;
        _player.MediaFailed += OnMediaFailed;
        _player.MediaEnded += OnMediaEnded;
        _player.PlaybackSession.PlaybackStateChanged += OnPlaybackStateChanged;
        _stallTimer = new Timer(OnStalled);
    }

    public event EventHandler? PlaybackFailed;

    public SystemMediaTransportControls MediaControls => _player.SystemMediaTransportControls;

    public double Volume
    {
        get => _player.Volume;
        set => _player.Volume = value;
    }

    public bool IsMuted
    {
        get => _player.IsMuted;
        set => _player.IsMuted = value;
    }

    public async Task OpenAsync(Uri uri, StreamType type, CancellationToken cancellationToken)
    {
        Stop();
        var opened = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        _pendingOpen = opened;
        using var registration = cancellationToken.Register(() => opened.TrySetCanceled(cancellationToken));

        try
        {
            MediaSource source;
            if (type == StreamType.Hls)
            {
                var result = await AdaptiveMediaSource.CreateFromUriAsync(uri).AsTask(cancellationToken);
                if (result.Status != AdaptiveMediaSourceCreationStatus.Success)
                    throw new InvalidOperationException($"HLS source could not be created: {result.Status}");
                source = MediaSource.CreateFromAdaptiveMediaSource(result.MediaSource);
            }
            else
            {
                source = MediaSource.CreateFromUri(uri);
            }

            if (_pendingOpen != opened)
            {
                source.Dispose();
                throw new OperationCanceledException(cancellationToken);
            }

            _source = source;
            _player.Source = source;
            _player.Play();
            await opened.Task;
        }
        catch
        {
            // Only tear down if a newer OpenAsync has not taken over the player.
            if (_pendingOpen == opened)
                Stop();
            throw;
        }
        finally
        {
            Interlocked.CompareExchange(ref _pendingOpen, null, opened);
        }
    }

    public void Stop()
    {
        _stallTimer.Change(Timeout.Infinite, Timeout.Infinite);
        _pendingOpen?.TrySetCanceled();
        _pendingOpen = null;
        _player.Pause();
        _player.Source = null;
        _source?.Dispose();
        _source = null;
    }

    private void OnMediaOpened(MediaPlayer sender, object args) => _pendingOpen?.TrySetResult();

    private void OnMediaFailed(MediaPlayer sender, MediaPlayerFailedEventArgs args)
    {
        var pending = _pendingOpen;
        if (pending is not null)
            pending.TrySetException(new InvalidOperationException($"{args.Error}: {args.ErrorMessage}", args.ExtendedErrorCode));
        else
            PlaybackFailed?.Invoke(this, EventArgs.Empty);
    }

    // A live stream should never end; treat it as a dropped connection.
    private void OnMediaEnded(MediaPlayer sender, object args) => PlaybackFailed?.Invoke(this, EventArgs.Empty);

    private void OnPlaybackStateChanged(MediaPlaybackSession session, object args)
    {
        if (session.PlaybackState == MediaPlaybackState.Buffering && _source is not null)
            _stallTimer.Change(StallTimeout, Timeout.InfiniteTimeSpan);
        else
            _stallTimer.Change(Timeout.Infinite, Timeout.Infinite);
    }

    private void OnStalled(object? state)
    {
        if (_pendingOpen is null && _source is not null
            && _player.PlaybackSession.PlaybackState == MediaPlaybackState.Buffering)
        {
            PlaybackFailed?.Invoke(this, EventArgs.Empty);
        }
    }

    public void Dispose()
    {
        Stop();
        _stallTimer.Dispose();
        _player.Dispose();
    }
}
