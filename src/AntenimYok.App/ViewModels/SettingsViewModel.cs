using System.Reflection;
using AntenimYok.App.Services;
using AntenimYok.Core.Playback;
using AntenimYok.Core.Settings;
using CommunityToolkit.Mvvm.ComponentModel;

namespace AntenimYok.App.ViewModels;

public sealed partial class SettingsViewModel : ObservableObject
{
    private readonly SettingsStore _settings;
    private readonly ThemeService _themes;

    private readonly SongTitleMonitor _songTitles;

    public SettingsViewModel(SettingsStore settings, ThemeService themes, SongTitleMonitor songTitles)
    {
        _settings = settings;
        _themes = themes;
        _songTitles = songTitles;
        ThemeIndex = (int)settings.Current.Theme;
        CloseToTray = settings.Current.CloseToTray;
        ShowSongTitles = settings.Current.ShowSongTitles;
    }

    [ObservableProperty]
    public partial bool ShowSongTitles { get; set; }

    partial void OnShowSongTitlesChanged(bool value)
    {
        _settings.Update(s => s with { ShowSongTitles = value });
        _songTitles.IsEnabled = value;
    }

    /// <summary>Index into Sistem / Açık / Koyu (same order as <see cref="AppTheme"/>).</summary>
    [ObservableProperty]
    public partial int ThemeIndex { get; set; }

    [ObservableProperty]
    public partial bool CloseToTray { get; set; }

    public string Version =>
        $"Sürüm {Assembly.GetExecutingAssembly().GetName().Version?.ToString(3) ?? "?"}";

    partial void OnThemeIndexChanged(int value)
    {
        if (value < 0)
            return;
        var theme = (AppTheme)value;
        _settings.Update(s => s with { Theme = theme });
        _themes.Apply(theme);
    }

    partial void OnCloseToTrayChanged(bool value) => _settings.Update(s => s with { CloseToTray = value });
}
