using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Threading.Tasks;
using AntenimYok.Core.Discovery;
using AntenimYok.Core.Stations;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Extensions.Logging;

namespace AntenimYok.App.ViewModels;

/// <summary>
/// Discover: every working Turkish station on Radio Browser, filtered by genre and by the title-bar search.
/// The list is downloaded once per session (~800 stations, one request) and filtered locally.
/// </summary>
public sealed partial class DiscoverViewModel : ObservableObject
{
    private const string CountryCode = "TR";

    private readonly RadioBrowserClient _client;
    private readonly MainViewModel _main;
    private readonly ILogger<DiscoverViewModel> _logger;
    private List<(DiscoveredStation Found, StationItem Item)> _all = [];

    public DiscoverViewModel(RadioBrowserClient client, MainViewModel main, ILogger<DiscoverViewModel> logger)
    {
        _client = client;
        _main = main;
        _logger = logger;
        _main.PropertyChanged += OnMainPropertyChanged;
    }

    public IReadOnlyList<Genre> Genres => Genre.Defaults;

    public ObservableCollection<StationItem> Results { get; } = [];

    [ObservableProperty]
    public partial Genre SelectedGenre { get; set; } = Genre.All;

    [ObservableProperty]
    public partial bool IsLoading { get; private set; }

    [ObservableProperty]
    public partial bool LoadFailed { get; private set; }

    [ObservableProperty]
    public partial bool HasNoResults { get; private set; }

    [ObservableProperty]
    public partial string CountText { get; private set; } = string.Empty;

    private bool IsLoaded => _all.Count > 0;

    /// <summary>Called when the page is shown; downloads the list the first time.</summary>
    public Task EnsureLoadedAsync() => IsLoaded || IsLoading ? Task.CompletedTask : LoadAsync();

    [RelayCommand]
    private async Task LoadAsync()
    {
        IsLoading = true;
        LoadFailed = false;
        try
        {
            var found = await _client.GetByCountryAsync(CountryCode);
            // Radio Browser lists some stations several times; keep the most voted entry per name (list is sorted by votes).
            _all = found
                .DistinctBy(f => StationSearch.Fold(f.Station.Name))
                .Select(f => (f, ToItem(f)))
                .ToList();
            ApplyFilter();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not load stations from Radio Browser");
            LoadFailed = true;
        }
        finally
        {
            IsLoading = false;
        }
    }

    /// <summary>Same station as a catalog entry → reuse it, so favorites, logo and playing state stay in sync.</summary>
    private StationItem ToItem(DiscoveredStation found)
    {
        var item = _main.FindKnown(found.Station) ?? _main.GetItem(found.Station);
        if (item.Subtitle.Length == 0)
            item.Subtitle = Describe(found);
        return item;
    }

    public void EnsureLogo(StationItem item) => _main.EnsureLogo(item);

    partial void OnSelectedGenreChanged(Genre value) => ApplyFilter();

    private void OnMainPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(MainViewModel.SearchText))
            ApplyFilter();
    }

    private void ApplyFilter()
    {
        if (!IsLoaded)
            return;

        var matches = _all
            .Where(x => SelectedGenre.Matches(x.Found) && StationSearch.Matches(x.Found.Station, _main.SearchText))
            .Select(x => x.Item)
            .Distinct()
            .ToList();

        Results.Clear();
        foreach (var item in matches)
            Results.Add(item);

        HasNoResults = matches.Count == 0;
        CountText = matches.Count == _all.Count
            ? $"Türkiye'den {_all.Count} radyo"
            : $"{matches.Count} / {_all.Count} radyo";
    }

    private static string Describe(DiscoveredStation found)
    {
        var parts = found.Tags.Take(3).ToList();
        var stream = found.Station.Streams.FirstOrDefault();
        if (stream?.Codec is { } codec)
            parts.Add(stream.Bitrate is { } kbps ? $"{codec} {kbps} kbps" : codec);
        return string.Join(" · ", parts);
    }
}
