using System;
using System.Collections.ObjectModel;
using System.Threading.Tasks;
using AntenimYok.Core.Playback;
using AntenimYok.Core.Stations;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Extensions.Logging;
using Microsoft.UI.Dispatching;

namespace AntenimYok.App.ViewModels;

public sealed partial class MainViewModel : ObservableObject
{
    private const double DefaultVolume = 50;

    private readonly StationRepository _repository;
    private readonly RadioPlayer _player;
    private readonly ILogger<MainViewModel> _logger;
    private readonly DispatcherQueue _dispatcher;

    public MainViewModel(StationRepository repository, RadioPlayer player, ILogger<MainViewModel> logger)
    {
        _repository = repository;
        _player = player;
        _logger = logger;
        _dispatcher = DispatcherQueue.GetForCurrentThread();
        _player.StateChanged += (_, _) => _dispatcher.TryEnqueue(SyncFromPlayer);
        _player.Volume = DefaultVolume / 100;
    }

    public ObservableCollection<Station> Stations { get; } = [];

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasStation), nameof(StationName), nameof(StationInitials), nameof(StatusText))]
    [NotifyCanExecuteChangedFor(nameof(TogglePlaybackCommand))]
    public partial Station? CurrentStation { get; private set; }

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsConnecting), nameof(IsActive), nameof(HasError), nameof(StatusText),
        nameof(PlayStopGlyph), nameof(PlayStopLabel))]
    public partial PlaybackState State { get; private set; }

    [ObservableProperty]
    public partial StationStream? CurrentStream { get; private set; }

    /// <summary>0 – 100</summary>
    [ObservableProperty]
    public partial double Volume { get; set; } = DefaultVolume;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(MuteGlyph), nameof(MuteLabel))]
    public partial bool IsMuted { get; set; }

    [ObservableProperty]
    public partial bool LoadFailed { get; private set; }

    public bool HasStation => CurrentStation is not null;
    public bool IsConnecting => State == PlaybackState.Connecting;
    public bool IsActive => State is PlaybackState.Connecting or PlaybackState.Playing;
    public bool HasError => State == PlaybackState.Error;

    public string StationName => CurrentStation?.Name ?? "Bir istasyon seçin";
    public string StationInitials => CurrentStation?.Initials ?? string.Empty;

    public string StatusText => State switch
    {
        PlaybackState.Connecting => "Bağlanıyor…",
        PlaybackState.Playing => FormatStream(CurrentStream),
        PlaybackState.Error => "Yayına ulaşılamadı",
        _ when CurrentStation is null => "Çalmak için listeden bir istasyona tıklayın",
        _ => "Durduruldu",
    };

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

    partial void OnVolumeChanged(double value)
    {
        _player.Volume = value / 100;
        if (value > 0 && IsMuted)
            IsMuted = false;
    }

    partial void OnIsMutedChanged(bool value) => _player.IsMuted = value;

    private void SyncFromPlayer()
    {
        CurrentStation = _player.CurrentStation;
        CurrentStream = _player.CurrentStream;
        State = _player.State;
        OnPropertyChanged(nameof(StatusText));
    }

    private static string FormatStream(StationStream? stream)
    {
        if (stream is null)
            return "Çalıyor";
        var details = stream.Bitrate is { } kbps ? $"{stream.Codec} {kbps} kbps".Trim() : stream.Codec;
        return string.IsNullOrEmpty(details) ? "Çalıyor" : $"Çalıyor · {details}";
    }
}
