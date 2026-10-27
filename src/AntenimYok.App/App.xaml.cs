using System;
using System.Net.Http;
using System.Net.NetworkInformation;
using AntenimYok.App.Services;
using AntenimYok.App.ViewModels;
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
    }

    public static new App Current => (App)Application.Current;

    public IServiceProvider Services { get; }

    private SettingsStore Settings => Services.GetRequiredService<SettingsStore>();

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        _window = new MainWindow(Services.GetRequiredService<MainViewModel>(), Settings);
        Services.GetRequiredService<ThemeService>().Register(_window);
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

    public void ShowMainWindow()
    {
        _miniPlayer?.HideAndRemember();
        _window?.ShowAndActivate();
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

    /// <summary>The close (X) button of either window: hide to the tray, or quit if that is turned off.</summary>
    public void CloseWindow(Window window)
    {
        if (!Settings.Current.CloseToTray)
        {
            ExitApp();
            return;
        }

        if (window == _miniPlayer)
            _miniPlayer.HideAndRemember();
        else
            window.AppWindow.Hide();
        Settings.Flush();
        _window?.ShowTrayHintOnce();
    }

    public void ExitApp()
    {
        Services.GetRequiredService<MainViewModel>().StopPlayback();
        _miniPlayer?.HideAndRemember();
        Settings.Flush();
        _window?.DisposeTrayIcon();
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
        services.AddSingleton<StationRepository>();
        services.AddSingleton<LogoCache>();
        services.AddSingleton<IStreamResolver, StreamResolver>();
        services.AddSingleton<MediaPlayerStreamPlayer>();
        services.AddSingleton<IStreamPlayer>(sp => sp.GetRequiredService<MediaPlayerStreamPlayer>());
        services.AddSingleton<RadioPlayer>();
        services.AddSingleton<MediaControlsService>();
        services.AddSingleton<ThemeService>();
        services.AddSingleton<MainViewModel>();
        services.AddSingleton<SettingsViewModel>();
        return services.BuildServiceProvider();
    }
}
