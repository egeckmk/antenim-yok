using System;
using System.Net.Http;
using System.Net.NetworkInformation;
using AntenimYok.App.Services;
using AntenimYok.App.ViewModels;
using AntenimYok.Core.Discovery;
using AntenimYok.Core.Playback;
using AntenimYok.Core.Settings;
using AntenimYok.Core.Stations;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.Windows.AppLifecycle;

namespace AntenimYok.App;

public partial class App : Application
{
    private MainWindow? _window;
    private MiniPlayerWindow? _miniPlayer;

    public App()
    {
        InitializeComponent();
        Services = ConfigureServices();
        UnhandledException += (_, e) => WriteCrashLog(e.Exception);
        AppDomain.CurrentDomain.UnhandledException += (_, e) => WriteCrashLog(e.ExceptionObject as Exception);
        System.Threading.Tasks.TaskScheduler.UnobservedTaskException += (_, e) => WriteCrashLog(e.Exception);
    }

    /// <summary>%LOCALAPPDATA%\AntenimYok\crash.log — the Debug logger is gone once the process dies.</summary>
    private static void WriteCrashLog(Exception? exception)
    {
        try
        {
            var dir = System.IO.Path.GetDirectoryName(SettingsStore.DefaultPath)!;
            System.IO.Directory.CreateDirectory(dir);
            System.IO.File.AppendAllText(System.IO.Path.Combine(dir, "crash.log"),
                $"{DateTime.Now:yyyy-MM-dd HH:mm:ss} {exception}{Environment.NewLine}{Environment.NewLine}");
        }
        catch
        {
            // Nothing left to report to.
        }
    }

    public static new App Current => (App)Application.Current;

    public IServiceProvider Services { get; }

    private SettingsStore Settings => Services.GetRequiredService<SettingsStore>();

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        _window = new MainWindow(Services.GetRequiredService<MainViewModel>(), Settings);
        Services.GetRequiredService<ThemeService>().Register(_window);
        try
        {
            Services.GetRequiredService<MediaControlsService>().Attach(WinRT.Interop.WindowNative.GetWindowHandle(_window));
        }
        catch (Exception ex)
        {
            // Without it only media keys / the Quick Settings card are missing; the app itself still works.
            Services.GetRequiredService<ILogger<App>>().LogError(ex, "Could not create the media session");
        }
        _window.Activate();

        // A second launch (see Program) lands here: bring the existing window back.
        var dispatcher = DispatcherQueue.GetForCurrentThread();
        AppInstance.GetCurrent().Activated += (_, _) => dispatcher.TryEnqueue(ShowMainWindow);

        // Network back (Wi-Fi reconnect, VPN, cable): a pending reconnect retries right away.
        var radio = Services.GetRequiredService<RadioPlayer>();
        NetworkChange.NetworkAddressChanged += (_, _) =>
        {
            if (NetworkInterface.GetIsNetworkAvailable())
                radio.NotifyNetworkAvailable();
        };
    }

    public void NavigateTo(string tag) => _window?.NavigateTo(tag);

    public void ShowMainWindow()
    {
        _miniPlayer?.HideAndRemember();
        _window?.ShowAndActivate();
    }

    /// <summary>Media card clicked while the main window is hidden: bring back whichever player is in use.</summary>
    public void ShowFromMediaCard()
    {
        if (_miniPlayer?.AppWindow.IsVisible == true)
            _miniPlayer.Activate();
        else
            ShowMainWindow();
    }

    public void ShowMiniPlayer()
    {
        if (_miniPlayer is null)
        {
            _miniPlayer = new MiniPlayerWindow(Services.GetRequiredService<MainViewModel>(), Settings);
            Services.GetRequiredService<ThemeService>().Register(_miniPlayer);
        }
        _window?.AppWindow.Hide();
        _miniPlayer.ShowAndActivate();
    }

    /// <summary>Set while quitting: windows then really close instead of hiding to the tray.</summary>
    public bool IsExiting { get; private set; }

    /// <summary>The close (X) button of either window: hide to the tray, or quit if that is turned off.</summary>
    public void CloseWindow(Window window)
    {
        if (!Settings.Current.CloseToTray)
        {
            // Not from inside the Closing event that called us.
            DispatcherQueue.GetForCurrentThread().TryEnqueue(ExitApp);
            return;
        }

        if (window == _miniPlayer)
            _miniPlayer.HideAndRemember();
        else
            window.AppWindow.Hide();
        Settings.Flush();
        _window?.ShowTrayHintOnce();
    }

    /// <summary>
    /// Quit in order: stop audio, drop the window-bound media session, remove the tray icon,
    /// close every window, then exit.
    /// </summary>
    public void ExitApp()
    {
        if (IsExiting)
            return;
        IsExiting = true;

        Services.GetRequiredService<MainViewModel>().StopPlayback();
        Services.GetRequiredService<MediaControlsService>().Detach();
        _miniPlayer?.HideAndRemember();
        Settings.Flush();

        _window?.RemoveTrayIcon();
        _miniPlayer?.Close();
        _window?.Close();
        Exit();
    }

    private static ServiceProvider ConfigureServices()
    {
        var services = new ServiceCollection();
        services.AddLogging(b => b.AddDebug().SetMinimumLevel(LogLevel.Debug));
        services.AddSingleton(_ =>
        {
            var http = new HttpClient { Timeout = TimeSpan.FromSeconds(15) };
            http.DefaultRequestHeaders.UserAgent.ParseAdd("AntenimYok/1.0");
            return http;
        });
        services.AddSingleton(sp => new SettingsStore(SettingsStore.DefaultPath, sp.GetRequiredService<ILogger<SettingsStore>>()));
        services.AddSingleton(sp => new FavoritesStore(FavoritesStore.DefaultPath, sp.GetRequiredService<ILogger<FavoritesStore>>()));
        services.AddSingleton<RadioBrowserClient>();
        services.AddSingleton<LogoCache>();
        services.AddSingleton<IStreamResolver, StreamResolver>();
        services.AddSingleton<MediaPlayerStreamPlayer>();
        services.AddSingleton<IStreamPlayer>(sp => sp.GetRequiredService<MediaPlayerStreamPlayer>());
        services.AddSingleton<RadioPlayer>();
        // Its own client: the metadata connection stays open as long as the station plays.
        services.AddSingleton<IIcyMetadataReader>(_ =>
        {
            var http = new HttpClient { Timeout = System.Threading.Timeout.InfiniteTimeSpan };
            http.DefaultRequestHeaders.UserAgent.ParseAdd("AntenimYok/1.0");
            return new IcyMetadataReader(http);
        });
        services.AddSingleton(sp => new SongTitleMonitor(
            sp.GetRequiredService<RadioPlayer>(), sp.GetRequiredService<IIcyMetadataReader>(),
            sp.GetRequiredService<ILogger<SongTitleMonitor>>())
        {
            IsEnabled = sp.GetRequiredService<SettingsStore>().Current.ShowSongTitles,
        });
        services.AddSingleton<MediaControlsService>();
        services.AddSingleton<ThemeService>();
        services.AddSingleton<MainViewModel>();
        services.AddSingleton<DiscoverViewModel>();
        services.AddSingleton<SettingsViewModel>();
        return services.BuildServiceProvider();
    }
}
