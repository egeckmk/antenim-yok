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

    public App()
    {
        InitializeComponent();
        Services = ConfigureServices();
    }

    public static new App Current => (App)Application.Current;

    public IServiceProvider Services { get; }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        _window = new MainWindow(Services.GetRequiredService<MainViewModel>(), Services.GetRequiredService<SettingsStore>());
        _window.Activate();

        // A second launch (see Program) lands here: bring the existing window back.
        var dispatcher = DispatcherQueue.GetForCurrentThread();
        AppInstance.GetCurrent().Activated += (_, _) => dispatcher.TryEnqueue(() => _window?.ShowAndActivate());

        // Network back (Wi-Fi reconnect, VPN, cable): a pending reconnect retries right away.
        var radio = Services.GetRequiredService<RadioPlayer>();
        NetworkChange.NetworkAddressChanged += (_, _) =>
        {
            if (NetworkInterface.GetIsNetworkAvailable())
                radio.NotifyNetworkAvailable();
        };
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
        services.AddSingleton<IStreamResolver, StreamResolver>();
        services.AddSingleton<MediaPlayerStreamPlayer>();
        services.AddSingleton<IStreamPlayer>(sp => sp.GetRequiredService<MediaPlayerStreamPlayer>());
        services.AddSingleton<RadioPlayer>();
        services.AddSingleton<MediaControlsService>();
        services.AddSingleton<MainViewModel>();
        return services.BuildServiceProvider();
    }
}
