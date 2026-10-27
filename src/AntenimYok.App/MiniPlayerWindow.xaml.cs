using System;
using System.IO;
using AntenimYok.App.ViewModels;
using AntenimYok.Core.Settings;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Windows.Graphics;

namespace AntenimYok.App;

/// <summary>Small always-on-top player (see docs/WIREFRAME.md). Remembers where it was.</summary>
public sealed partial class MiniPlayerWindow : Window
{
    private static readonly SizeInt32 Size = new(420, 148);
    private const int ScreenMargin = 24;

    private readonly SettingsStore _settings;

    public MiniPlayerWindow(MainViewModel viewModel, SettingsStore settings)
    {
        ViewModel = viewModel;
        _settings = settings;
        InitializeComponent();

        ExtendsContentIntoTitleBar = true;
        SetTitleBar(DragArea);
        AppWindow.SetIcon(Path.Combine(AppContext.BaseDirectory, "Assets", "AppIcon.ico"));

        var presenter = OverlappedPresenter.CreateForToolWindow();
        presenter.IsAlwaysOnTop = true;
        presenter.IsResizable = false;
        presenter.IsMaximizable = false;
        presenter.IsMinimizable = false;
        AppWindow.SetPresenter(presenter);
        AppWindow.Resize(Size);
        AppWindow.Closing += OnClosing;
    }

    public MainViewModel ViewModel { get; }

    public void ShowAndActivate()
    {
        AppWindow.Move(GetStartPosition());
        AppWindow.Show();
        Activate();
    }

    public void HideAndRemember()
    {
        if (!AppWindow.IsVisible)
            return;
        _settings.Update(s => s with { MiniPlayerPosition = new WindowPosition(AppWindow.Position.X, AppWindow.Position.Y) });
        AppWindow.Hide();
    }

    private void OnExpandClick(object sender, RoutedEventArgs e) => App.Current.ShowMainWindow();

    private void OnClosing(AppWindow sender, AppWindowClosingEventArgs args)
    {
        if (App.Current.IsExiting)
            return;
        args.Cancel = true;
        App.Current.CloseWindow(this);
    }

    /// <summary>Last position if it is still on a screen, otherwise bottom-right of the primary work area.</summary>
    private PointInt32 GetStartPosition()
    {
        if (_settings.Current.MiniPlayerPosition is { } saved)
        {
            var point = new PointInt32(saved.X, saved.Y);
            var area = DisplayArea.GetFromPoint(point, DisplayAreaFallback.None);
            if (area is not null)
            {
                var work = area.WorkArea;
                return new PointInt32(
                    Math.Clamp(saved.X, work.X, work.X + work.Width - Size.Width),
                    Math.Clamp(saved.Y, work.Y, work.Y + work.Height - Size.Height));
            }
        }

        var primary = DisplayArea.Primary.WorkArea;
        return new PointInt32(
            primary.X + primary.Width - Size.Width - ScreenMargin,
            primary.Y + primary.Height - Size.Height - ScreenMargin);
    }
}
