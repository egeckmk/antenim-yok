using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;
using AntenimYok.App.Services;
using AntenimYok.Core.Playback;
using AntenimYok.Core.Settings;
using AntenimYok.Core.Stations;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Extensions.Logging;
using Microsoft.UI.Dispatching;

namespace AntenimYok.App.ViewModels;

public sealed partial class MainViewModel : ObservableObject
{
    private readonly StationRepository _repository;
    private readonly RadioPlayer _player;
    private readonly SettingsStore _settings;
    private readonly ILogger<MainViewModel> _logger;
    private readonly DispatcherQueue _dispatcher;

    public MainViewModel(
        StationRepository repository,
        RadioPlayer player,
        SettingsStore settings,
        MediaControlsService mediaControls,
        ILogger<MainViewModel> logger)
    {
        _repository = repository;
        _player = player;
        _settings = settings;
        _logger = logger;
        _dispatcher = DispatcherQueue.GetForCurrentThread();
        _player.StateChanged += (_, _) => _dispatcher.TryEnqueue(SyncFromPlayer);
        mediaControls.CommandReceived += (_, command) => _dispatcher.TryEnqueue(() => _ = HandleMediaCommandAsync(command));

        Volume = settings.Current.Volume * 100;
        IsMuted = settings.Current.IsMuted;
        _player.Volume = settings.Current.Volume;
        _player.IsMuted = settings.Current.IsMuted;
    }

    public ObservableCollection<Station> Stations { get; } = [];

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasStation), nameof(StationName), nameof(StationInitials), nameof(StatusText), nameof(TrayToolTip))]
    [NotifyCanExecuteChangedFor(nameof(TogglePlaybackCommand))]
    public partial Station? CurrentStation { get; private set; }

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsConnecting), nameof(IsActive), nameof(HasError), nameof(StatusText),
        nameof(PlayStopGlyph), nameof(PlayStopLabel), nameof(TrayToolTip))]
    public partial PlaybackState State { get; private set; }

    [ObservableProperty]
    public partial StationStream? CurrentStream { get; private set; }

    /// <summary>0 – 100</summary>
    [ObservableProperty]
    public partial double Volume { get; set; }

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(MuteGlyph), nameof(MuteLabel))]
    public partial bool IsMuted { get; set; }

    [ObservableProperty]
    public partial bool LoadFailed { get; private set; }

    public bool HasStation => CurrentStation is not null;
    public bool IsConnecting => State is PlaybackState.Connecting or PlaybackState.Reconnecting;
    public bool IsActive => State is PlaybackState.Connecting or PlaybackState.Playing or PlaybackState.Reconnecting;
    public bool HasError => State == PlaybackState.Error;

    public string StationName => CurrentStation?.Name ?? "Bir istasyon seçin";
    public string StationInitials => CurrentStation?.Initials ?? string.Empty;

    public string StatusText => State switch
    {
        PlaybackState.Connecting => "Bağlanıyor…",
        PlaybackState.Reconnecting => "Bağlantı koptu, yeniden bağlanıyor…",
        PlaybackState.Playing => FormatStream(CurrentStream),
        PlaybackState.Error => "Yayına ulaşılamadı",
        _ when CurrentStation is null => "Çalmak için listeden bir istasyona tıklayın",
        _ => "Durduruldu",
    };

    public string TrayToolTip => CurrentStation is { } station && IsActive
        ? $"Antenim Yok — {station.Name}"
        : "Antenim Yok";

    public string PlayStopGlyph => IsActive ? "" : ""; // Stop / Play
    public string PlayStopLabel => IsActive ? "Durdur" : "Çal";
    public string MuteGlyph => IsMuted ? "" : ""; // Mute / Volume
    public string MuteLabel => IsMuted ? "Sesi aç" : "Sesi kapat";

    [RelayCommand]
    private async Task LoadAsync()
    {
        try
        {
            LoadFailed = false;
            var stations = await _repository.LoadEmbeddedAsync();
            Stations.Clear();
            foreach (var station in stations)
                Stations.Add(station);

            // Show the last station in the bar (not auto-playing).
            CurrentStation ??= Stations.FirstOrDefault(s => s.Id == _settings.Current.LastStationId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not load stations");
            LoadFailed = true;
        }
    }

    /// <summary>Clicking the station that is already playing stops it.</summary>
    [RelayCommand]
    private async Task PlayStationAsync(Station station)
    {
        if (station == CurrentStation && IsActive)
        {
            _player.Stop();
            return;
        }
        await _player.PlayAsync(station);
    }

    [RelayCommand(CanExecute = nameof(HasStation))]
    private async Task TogglePlaybackAsync()
    {
        if (IsActive)
            _player.Stop();
        else if (CurrentStation is { } station)
            await _player.PlayAsync(station);
    }

    [RelayCommand]
    private async Task RetryAsync()
    {
        if (CurrentStation is { } station)
            await _player.PlayAsync(station);
    }

    [RelayCommand]
    private void ToggleMute() => IsMuted = !IsMuted;

    public void StopPlayback() => _player.Stop();

    private async Task HandleMediaCommandAsync(MediaCommand command)
    {
        switch (command)
        {
            case MediaCommand.Play when !IsActive && CurrentStation is { } station:
                await _player.PlayAsync(station);
                break;
            case MediaCommand.Stop when IsActive:
                _player.Stop();
                break;
            case MediaCommand.Next:
                await PlayRelativeAsync(+1);
                break;
            case MediaCommand.Previous:
                await PlayRelativeAsync(-1);
                break;
        }
    }

    private async Task PlayRelativeAsync(int offset)
    {
        if (Stations.Count == 0)
            return;
        var index = CurrentStation is null ? -1 : Stations.IndexOf(CurrentStation);
        var next = index < 0
            ? Stations[0]
            : Stations[((index + offset) % Stations.Count + Stations.Count) % Stations.Count];
        await _player.PlayAsync(next);
    }

    partial void OnVolumeChanged(double value)
    {
        _player.Volume = value / 100;
        _settings.Update(s => s with { Volume = Math.Round(value) / 100 });
        if (value > 0 && IsMuted)
            IsMuted = false;
    }

    partial void OnIsMutedChanged(bool value)
    {
        _player.IsMuted = value;
        _settings.Update(s => s with { IsMuted = value });
    }

    private void SyncFromPlayer()
    {
        CurrentStation = _player.CurrentStation ?? CurrentStation;
        CurrentStream = _player.CurrentStream;
        State = _player.State;
        OnPropertyChanged(nameof(StatusText));

        if (State == PlaybackState.Playing && CurrentStation is { } station)
            _settings.Update(s => s with { LastStationId = station.Id });
    }

    private static string FormatStream(StationStream? stream)
    {
        if (stream is null)
            return "Çalıyor";
        var details = stream.Bitrate is { } kbps ? $"{stream.Codec} {kbps} kbps".Trim() : stream.Codec;
        return string.IsNullOrEmpty(details) ? "Çalıyor" : $"Çalıyor · {details}";
    }
}
