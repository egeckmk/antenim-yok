using System;
using System.IO;
using System.Runtime.InteropServices;
using AntenimYok.Core.Playback;
using AntenimYok.Core.Stations;
using Microsoft.Extensions.Logging;
using Microsoft.UI.Dispatching;
using Windows.Media;
using Windows.Storage;
using Windows.Storage.Streams;
using WinRT;

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
/// The session is tied to the main window, so clicking the media card in Quick Settings brings that window up.
/// </summary>
public sealed class MediaControlsService(RadioPlayer radio, LogoCache logos, ILogger<MediaControlsService> logger)
{
    private static readonly Guid SystemMediaTransportControlsIid = new("99FA3FF4-1742-42A6-902E-087D41F965EC");

    private SystemMediaTransportControls? _controls;
    private DispatcherQueue? _dispatcher;
    private Station? _shownStation;

    /// <summary>Raised on a background thread.</summary>
    public event EventHandler<MediaCommand>? CommandReceived;

    /// <summary>Creates the session for <paramref name="windowHandle"/>; call once the main window exists.</summary>
    public void Attach(IntPtr windowHandle)
    {
        _dispatcher = DispatcherQueue.GetForCurrentThread();
        var interop = SystemMediaTransportControls.As<ISystemMediaTransportControlsInterop>();
        var iid = SystemMediaTransportControlsIid;
        var abi = interop.GetForWindow(windowHandle, ref iid);
        try
        {
            _controls = MarshalInspectable<SystemMediaTransportControls>.FromAbi(abi);
        }
        finally
        {
            Marshal.Release(abi);
        }

        _controls.IsPlayEnabled = true;
        _controls.IsPauseEnabled = true;
        _controls.IsStopEnabled = true;
        _controls.IsNextEnabled = true;
        _controls.IsPreviousEnabled = true;
        _controls.ButtonPressed += OnButtonPressed;
        radio.StateChanged += OnRadioStateChanged;
        Update();
    }

    /// <summary>Drops the session before the window it belongs to goes away (on exit).</summary>
    public void Detach()
    {
        if (_controls is null)
            return;
        radio.StateChanged -= OnRadioStateChanged;
        _controls.ButtonPressed -= OnButtonPressed;
        _controls.IsEnabled = false;
        _controls = null;
    }

    // RadioPlayer may raise this on a background thread; the window-bound session is used from the UI thread only.
    private void OnRadioStateChanged(object? sender, EventArgs e) => _dispatcher?.TryEnqueue(Update);

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
        if (_controls is null)
            return;

        // The card only shows up once something has played.
        _controls.IsEnabled = radio.CurrentStation is not null;
        _controls.PlaybackStatus = radio.State switch
        {
            PlaybackState.Playing => MediaPlaybackStatus.Playing,
            PlaybackState.Connecting or PlaybackState.Reconnecting => MediaPlaybackStatus.Changing,
            _ => MediaPlaybackStatus.Stopped,
        };

        var station = radio.CurrentStation;
        if (station is null || station == _shownStation)
            return;
        _shownStation = station;
        UpdateDisplay(_controls, station);
    }

    private async void UpdateDisplay(SystemMediaTransportControls controls, Station station)
    {
        try
        {
            var updater = controls.DisplayUpdater;
            updater.ClearAll();
            updater.Type = MediaPlaybackType.Music;
            updater.MusicProperties.Title = station.Name;
            updater.MusicProperties.Artist = "Antenim Yok";

            updater.Update();

            // Cached PNG: works for ICO/WebP logos and when the logo host is blocked later.
            var imagePath = await logos.GetPathAsync(station)
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
            logger.LogWarning(ex, "Could not update media overlay for {Station}", station.Name);
        }
    }

    // IInspectable-based; .NET only marshals IUnknown, so the three IInspectable slots are declared as placeholders.
    [ComImport]
    [Guid("ddb0472d-c911-4a1f-86d9-dc3d71a95f5a")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface ISystemMediaTransportControlsInterop
    {
        void GetIids();
        void GetRuntimeClassName();
        void GetTrustLevel();

        IntPtr GetForWindow(IntPtr appWindow, ref Guid riid);
    }
}
