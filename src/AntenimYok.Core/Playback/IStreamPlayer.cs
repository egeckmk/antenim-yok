using AntenimYok.Core.Stations;

namespace AntenimYok.Core.Playback;

/// <summary>Platform audio player (Windows: MediaPlayer). Kept behind an interface so playback logic is testable.</summary>
public interface IStreamPlayer
{
    /// <summary>Starts playing <paramref name="uri"/>; completes once the media has opened, throws if it fails.</summary>
    Task OpenAsync(Uri uri, StreamType type, CancellationToken cancellationToken);

    void Stop();

    /// <summary>0.0 – 1.0</summary>
    double Volume { get; set; }

    bool IsMuted { get; set; }

    /// <summary>Raised when an already opened stream fails or ends.</summary>
    event EventHandler? PlaybackFailed;
}
