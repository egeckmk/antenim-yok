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
    private readonly StartupService _startup;
    private readonly UpdateService _updates;

    public SettingsViewModel(
        SettingsStore settings, ThemeService themes, SongTitleMonitor songTitles, StartupService startup, UpdateService updates)
    {
        _settings = settings;
        _themes = themes;
        _songTitles = songTitles;
        _startup = startup;
        _updates = updates;
        var dispatcher = Microsoft.UI.Dispatching.DispatcherQueue.GetForCurrentThread();
        updates.StatusChanged += (_, _) => dispatcher.TryEnqueue(() => OnPropertyChanged(nameof(UpdateStatusText)));
        ThemeIndex = (int)settings.Current.Theme;
        CloseToTray = settings.Current.CloseToTray;
        ShowSongTitles = settings.Current.ShowSongTitles;
        StartWithWindows = startup.IsEnabled;
    }

    public bool CanCheckForUpdates => _updates.IsInstalled;

    public string UpdateStatusText => _updates.Status switch
    {
        UpdateStatus.NotInstalled => "Bu kopya kurulum (Setup.exe) ile kurulmadığı için güncellenmez.",
        UpdateStatus.Checking => "Denetleniyor…",
        UpdateStatus.UpToDate => "Güncel.",
        UpdateStatus.Downloading => $"Antenim Yok {_updates.NewVersion} indiriliyor…",
        UpdateStatus.ReadyToRestart => $"Antenim Yok {_updates.NewVersion} hazır; yeniden başlatınca yüklenir.",
        UpdateStatus.Failed => "Güncelleme denetlenemedi (internet ya da GitHub'a ulaşılamıyor). Daha sonra yeniden denenir.",
        _ => "Yeni sürümler açılışta ve birkaç saatte bir denetlenir.",
    };

    [CommunityToolkit.Mvvm.Input.RelayCommand]
    private System.Threading.Tasks.Task CheckForUpdatesAsync() => _updates.CheckAsync();

    /// <summary>Kept in the registry (Run key), not in settings.json.</summary>
    [ObservableProperty]
    public partial bool StartWithWindows { get; set; }

    partial void OnStartWithWindowsChanged(bool value)
    {
        if (_startup.IsEnabled != value)
            _startup.IsEnabled = value;
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

    /// <summary>"Sürüm 0.4.0 (abc1234)" from Directory.Build.props + the commit the SDK appends ("0.4.0+&lt;sha&gt;").</summary>
    public string Version
    {
        get
        {
            var informational = Assembly.GetExecutingAssembly()
                .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion ?? "?";
            var parts = informational.Split('+', 2);
            return parts.Length == 2 && parts[1].Length >= 7
                ? $"Sürüm {parts[0]} ({parts[1][..7]})"
                : $"Sürüm {parts[0]}";
        }
    }

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
