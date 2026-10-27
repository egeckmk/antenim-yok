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
using Microsoft.UI.Xaml.Media.Imaging;
using Windows.Storage;
using Windows.Storage.Streams;

namespace AntenimYok.App.ViewModels;

public sealed partial class MainViewModel : ObservableObject
{
    private const double VolumeStep = 5;

    private readonly StationRepository _repository;
    private readonly RadioPlayer _player;
    private readonly SettingsStore _settings;
    private readonly LogoCache _logos;
    private readonly ILogger<MainViewModel> _logger;
    private readonly DispatcherQueue _dispatcher;

    public MainViewModel(
        StationRepository repository,
        RadioPlayer player,
        SettingsStore settings,
        LogoCache logos,
        MediaControlsService mediaControls,
        ILogger<MainViewModel> logger)
    {
        _repository = repository;
        _player = player;
        _settings = settings;
        _logos = logos;
        _logger = logger;
        _dispatcher = DispatcherQueue.GetForCurrentThread();
        _player.StateChanged += (_, _) => _dispatcher.TryEnqueue(SyncFromPlayer);
        mediaControls.CommandReceived += (_, command) => _dispatcher.TryEnqueue(() => _ = HandleMediaCommandAsync(command));

        Volume = settings.Current.Volume * 100;
        IsMuted = settings.Current.IsMuted;
        _player.Volume = settings.Current.Volume;
        _player.IsMuted = settings.Current.IsMuted;
    }

    /// <summary>Favorites, in order (Ctrl+1…9, next/previous).</summary>
    public ObservableCollection<StationItem> Stations { get; } = [];

    /// <summary><see cref="Stations"/> filtered by <see cref="SearchText"/>.</summary>
    public ObservableCollection<StationItem> VisibleStations { get; } = [];

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasStation), nameof(StationName), nameof(CurrentItem), nameof(StatusText), nameof(TrayToolTip))]
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

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(NoResultsText))]
    public partial string SearchText { get; set; } = string.Empty;

    [ObservableProperty]
    public partial bool HasNoResults { get; private set; }

    public bool HasStation => CurrentStation is not null;
    public bool IsConnecting => State is PlaybackState.Connecting or PlaybackState.Reconnecting;
    public bool IsActive => State is PlaybackState.Connecting or PlaybackState.Playing or PlaybackState.Reconnecting;
    public bool HasError => State == PlaybackState.Error;

    public string StationName => CurrentStation?.Name ?? "Bir istasyon seçin";
    public StationItem? CurrentItem => Stations.FirstOrDefault(i => i.Station == CurrentStation);

    public string StatusText => State switch
    {
        PlaybackState.Connecting => "Bağlanıyor…",
        PlaybackState.Reconnecting => "Bağlantı koptu, yeniden bağlanıyor…",
        PlaybackState.Playing => FormatStream(CurrentStream),
        PlaybackState.Error => "Yayına ulaşılamadı",
        _ when CurrentStation is null => "Çalmak için bir istasyona tıklayın",
        _ => "Durduruldu",
    };

    public string NoResultsText => $"“{SearchText.Trim()}” ile eşleşen istasyon yok.";

    public string TrayToolTip => CurrentStation is { } station && IsActive
        ? $"Antenim Yok — {station.Name}"
        : "Antenim Yok";

    public string PlayStopGlyph => Glyph(IsActive ? 0xE71A : 0xE768); // Stop / Play
    public string PlayStopLabel => IsActive ? "Durdur" : "Çal";
    public string MuteGlyph => Glyph(IsMuted ? 0xE74F : 0xE767); // Mute / Volume
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
            {
                var item = new StationItem(station);
                Stations.Add(item);
                _ = LoadLogoAsync(item);
            }
            ApplyFilter();

            // Show the last station in the bar (not auto-playing).
            CurrentStation ??= stations.FirstOrDefault(s => s.Id == _settings.Current.LastStationId);
            OnPropertyChanged(nameof(CurrentItem));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not load stations");
            LoadFailed = true;
        }
    }

    private async Task LoadLogoAsync(StationItem item)
    {
        try
        {
            if (await _logos.GetPathAsync(item.Station) is not { } path)
                return;
            var bitmap = new BitmapImage();
            using (var stream = await FileRandomAccessStream.OpenAsync(path, FileAccessMode.Read))
                await bitmap.SetSourceAsync(stream);
            item.Logo = bitmap;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not show logo for {Station}", item.Name);
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
    private Task PlayNextAsync() => PlayRelativeAsync(+1);

    [RelayCommand]
    private Task PlayPreviousAsync() => PlayRelativeAsync(-1);

    /// <summary>Ctrl+1…9: the n-th favorite (0-based index).</summary>
    public async Task PlayFavoriteAsync(int index)
    {
        if (index >= 0 && index < Stations.Count)
            await _player.PlayAsync(Stations[index].Station);
    }

    [RelayCommand]
    private void ToggleMute() => IsMuted = !IsMuted;

    public void ChangeVolume(int direction) => Volume = Math.Clamp(Volume + direction * VolumeStep, 0, 100);

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
        var index = CurrentItem is { } current ? Stations.IndexOf(current) : -1;
        var next = index < 0
            ? Stations[0]
            : Stations[((index + offset) % Stations.Count + Stations.Count) % Stations.Count];
        await _player.PlayAsync(next.Station);
    }

    partial void OnSearchTextChanged(string value) => ApplyFilter();

    private void ApplyFilter()
    {
        var matches = Stations.Where(i => StationSearch.Matches(i.Station, SearchText)).ToList();
        if (!matches.SequenceEqual(VisibleStations))
        {
            VisibleStations.Clear();
            foreach (var item in matches)
                VisibleStations.Add(item);
        }
        HasNoResults = Stations.Count > 0 && matches.Count == 0;
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
        // Item flags first: State/CurrentStation listeners (tray menu) read them.
        var station = _player.CurrentStation ?? CurrentStation;
        foreach (var item in Stations)
            item.IsPlaying = _player.IsActive && item.Station == station;

        CurrentStation = station;
        CurrentStream = _player.CurrentStream;
        State = _player.State;
        OnPropertyChanged(nameof(StatusText));

        if (State == PlaybackState.Playing && station is not null)
            _settings.Update(s => s with { LastStationId = station.Id });
    }

    // Segoe Fluent Icons code point.
    private static string Glyph(int codePoint) => char.ConvertFromUtf32(codePoint);

    private static string FormatStream(StationStream? stream)
    {
        if (stream is null)
            return "Çalıyor";
        var details = stream.Bitrate is { } kbps ? $"{stream.Codec} {kbps} kbps".Trim() : stream.Codec;
        return string.IsNullOrEmpty(details) ? "Çalıyor" : $"Çalıyor · {details}";
    }
}
