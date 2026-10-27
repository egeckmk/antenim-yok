using AntenimYok.Core.Stations;
using Microsoft.Extensions.Logging;

namespace AntenimYok.Core.Playback;

/// <summary>
/// Follows <see cref="RadioPlayer"/>: while an Icecast stream plays, reads its song titles
/// (<see cref="IIcyMetadataReader"/>); otherwise the title is empty. HLS streams have no titles here.
/// </summary>
public sealed class SongTitleMonitor
{
    private readonly RadioPlayer _player;
    private readonly IIcyMetadataReader _reader;
    private readonly ILogger<SongTitleMonitor> _logger;
    private readonly Lock _gate = new();
    private CancellationTokenSource? _readCts;
    private Uri? _readingUrl;

    public SongTitleMonitor(RadioPlayer player, IIcyMetadataReader reader, ILogger<SongTitleMonitor> logger)
    {
        _player = player;
        _reader = reader;
        _logger = logger;
        _player.StateChanged += (_, _) => OnPlayerStateChanged();
    }

    /// <summary>Off: no extra connection is opened (it roughly doubles the data used).</summary>
    public bool IsEnabled
    {
        get;
        set
        {
            field = value;
            OnPlayerStateChanged();
        }
    } = true;

    /// <summary>Wait before reconnecting when the metadata connection drops while the radio still plays.</summary>
    public TimeSpan RetryDelay { get; init; } = TimeSpan.FromSeconds(20);

    public string? CurrentTitle { get; private set; }

    /// <summary>Raised on a background thread.</summary>
    public event EventHandler? TitleChanged;

    private void OnPlayerStateChanged()
    {
        var url = IsEnabled && _player.State == PlaybackState.Playing
            && _player.CurrentStream is { Type: StreamType.Icecast }
            ? _player.CurrentUrl
            : null;

        CancellationTokenSource? start = null;
        lock (_gate)
        {
            if (url == _readingUrl)
                return;
            _readCts?.Cancel();
            _readCts = null;
            _readingUrl = url;
            if (url is not null)
                _readCts = start = new CancellationTokenSource();
        }

        SetTitle(null);
        if (start is not null)
            _ = ReadLoopAsync(url!, start.Token);
    }

    private async Task ReadLoopAsync(Uri url, CancellationToken token)
    {
        while (!token.IsCancellationRequested)
        {
            try
            {
                await foreach (var title in _reader.ReadTitlesAsync(url, token))
                {
                    if (!token.IsCancellationRequested)
                        SetTitle(title);
                }
                return; // Stream has no metadata (or ended): nothing more to read.
            }
            catch (OperationCanceledException) when (token.IsCancellationRequested)
            {
                return;
            }
            catch (Exception ex)
            {
                _logger.LogDebug(ex, "Song title connection dropped for {Url}", url);
            }

            try
            {
                await Task.Delay(RetryDelay, token);
            }
            catch (OperationCanceledException)
            {
                return;
            }
        }
    }

    private void SetTitle(string? title)
    {
        if (title == CurrentTitle)
            return;
        CurrentTitle = title;
        TitleChanged?.Invoke(this, EventArgs.Empty);
    }
}
