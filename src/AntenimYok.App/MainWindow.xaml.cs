using System;
using System.IO;
using AntenimYok.App.ViewModels;
using AntenimYok.Core.Settings;
using AntenimYok.Core.Stations;
using CommunityToolkit.Mvvm.Input;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AntenimYok.App;

public sealed partial class MainWindow : Window
{
    private readonly SettingsStore _settings;
    private bool _isExiting;
    private bool _trayHintShown;

    public MainWindow(MainViewModel viewModel, SettingsStore settings)
    {
        ViewModel = viewModel;
        _settings = settings;
        InitializeComponent();

        var iconPath = Path.Combine(AppContext.BaseDirectory, "Assets", "AppIcon.ico");
        AppWindow.SetIcon(iconPath);
        TrayIcon.Icon = new System.Drawing.Icon(iconPath);
        AppWindow.Resize(new Windows.Graphics.SizeInt32(960, 640));
        AppWindow.Closing += OnClosing;

        ViewModel.LoadCommand.Execute(null);
    }

    public MainViewModel ViewModel { get; }

    [RelayCommand]
    public void ShowAndActivate()
    {
        AppWindow.Show();
        if (AppWindow.Presenter is OverlappedPresenter { State: OverlappedPresenterState.Minimized } presenter)
            presenter.Restore();
        Activate();
    }

    [RelayCommand]
    private void Exit()
    {
        _isExiting = true;
        ViewModel.StopPlayback();
        _settings.Flush();
        TrayIcon.Dispose();
        Application.Current.Exit();
    }

    // Closing the window keeps the radio playing in the tray; "Çıkış" in the tray menu really quits.
    private void OnClosing(AppWindow sender, AppWindowClosingEventArgs args)
    {
        if (_isExiting)
            return;

        args.Cancel = true;
        AppWindow.Hide();
        _settings.Flush();

        if (!_trayHintShown && ViewModel.IsActive)
        {
            _trayHintShown = true;
            TrayIcon.ShowNotification("Antenim Yok çalmaya devam ediyor",
                "Simge durumundaki tepsi simgesinden açabilir veya çıkabilirsiniz.");
        }
    }

    private void OnStationClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is Station station)
            ViewModel.PlayStationCommand.Execute(station);
    }
}
