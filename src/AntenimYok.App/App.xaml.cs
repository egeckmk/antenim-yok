using System;
using System.Net.Http;
using AntenimYok.App.Services;
using AntenimYok.App.ViewModels;
using AntenimYok.Core.Playback;
using AntenimYok.Core.Stations;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.UI.Xaml;

namespace AntenimYok.App;

public partial class App : Application
{
    private Window? _window;

    public App()
    {
        InitializeComponent();
        Services = ConfigureServices();
    }

    public static new App Current => (App)Application.Current;

    public IServiceProvider Services { get; }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        _window = new MainWindow(Services.GetRequiredService<MainViewModel>());
        _window.Activate();
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
        services.AddSingleton<StationRepository>();
        services.AddSingleton<IStreamResolver, StreamResolver>();
        services.AddSingleton<IStreamPlayer, MediaPlayerStreamPlayer>();
        services.AddSingleton<RadioPlayer>();
        services.AddSingleton<MainViewModel>();
        return services.BuildServiceProvider();
    }
}
