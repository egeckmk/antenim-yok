using System;
using System.IO;
using AntenimYok.Core.Playback;
using AntenimYok.Core.Stations;
using Microsoft.Extensions.Logging;
using Windows.Media;
using Windows.Storage;
using Windows.Storage.Streams;

namespace AntenimYok.App.Services;

public enum MediaCommand
{
    Play,
    Stop,
    Next,
    Previous,
}

/// <summary>
/// Windows media overlay / keyboard media keys (SystemMediaTransportControls):
/// shows the station and forwards button presses as <see cref="MediaCommand"/>s.
/// </summary>
public sealed class MediaControlsService
{
    private readonly SystemMediaTransportControls _controls;
    private readonly RadioPlayer _radio;
    private readonly LogoCache _logos;
    private readonly ILogger<MediaControlsService> _logger;
    private Station? _shownStation;

    public MediaControlsService(MediaPlayerStreamPlayer player, RadioPlayer radio, LogoCache logos, ILogger<MediaControlsService> logger)
    {
        _controls = player.MediaControls;
        _radio = radio;
        _logos = logos;
        _logger = logger;

        _controls.IsEnabled = true;
        _controls.IsPlayEnabled = true;
        _controls.IsPauseEnabled = true;
        _controls.IsStopEnabled = true;
        _controls.IsNextEnabled = true;
        _controls.IsPreviousEnabled = true;
        _controls.ButtonPressed += OnButtonPressed;
        _radio.StateChanged += (_, _) => Update();
    }

    /// <summary>Raised on a background thread.</summary>
    public event EventHandler<MediaCommand>? CommandReceived;

    private void OnButtonPressed(SystemMediaTransportControls sender, SystemMediaTransportControlsButtonPressedEventArgs args)
    {
        MediaCommand? command = args.Button switch
        {
            SystemMediaTransportControlsButton.Play => MediaCommand.Play,
            // Live radio cannot pause; pause means stop.
            SystemMediaTransportControlsButton.Pause or SystemMediaTransportControlsButton.Stop => MediaCommand.Stop,
            SystemMediaTransportControlsButton.Next => MediaCommand.Next,
            SystemMediaTransportControlsButton.Previous => MediaCommand.Previous,
            _ => null,
        };
        if (command is { } c)
            CommandReceived?.Invoke(this, c);
    }

    private void Update()
    {
        _controls.PlaybackStatus = _radio.State switch
        {
            PlaybackState.Playing => MediaPlaybackStatus.Playing,
            PlaybackState.Connecting or PlaybackState.Reconnecting => MediaPlaybackStatus.Changing,
            _ => MediaPlaybackStatus.Stopped,
        };

        var station = _radio.CurrentStation;
        if (station is null || station == _shownStation)
            return;
        _shownStation = station;
        UpdateDisplay(station);
    }

    private async void UpdateDisplay(Station station)
    {
        try
        {
            var updater = _controls.DisplayUpdater;
            updater.ClearAll();
            updater.Type = MediaPlaybackType.Music;
            updater.MusicProperties.Title = station.Name;
            updater.MusicProperties.Artist = "Antenim Yok";

            updater.Update();

            // Cached PNG: works for ICO/WebP logos and when the logo host is blocked later.
            var imagePath = await _logos.GetPathAsync(station)
                ?? Path.Combine(AppContext.BaseDirectory, "Assets", "AppIcon.png");
            var file = await StorageFile.GetFileFromPathAsync(imagePath);
            if (_shownStation != station)
                return;
            updater.Thumbnail = RandomAccessStreamReference.CreateFromFile(file);
            updater.Update();
        }
        catch (Exception ex)
        {
            // async void: never let this escape.
            _logger.LogWarning(ex, "Could not update media overlay for {Station}", station.Name);
        }
    }
}
