using System;
using System.ComponentModel;
using System.IO;
using System.Linq;
using AntenimYok.App.ViewModels;
using AntenimYok.App.Views;
using AntenimYok.Core.Settings;
using CommunityToolkit.Mvvm.Input;
using Microsoft.UI.Input;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Input;
using Windows.System;

namespace AntenimYok.App;

public sealed partial class MainWindow : Window
{
    private readonly SettingsStore _settings;
    private bool _trayHintShown;

    public MainWindow(MainViewModel viewModel, SettingsStore settings)
    {
        ViewModel = viewModel;
        _settings = settings;
        InitializeComponent();

        ExtendsContentIntoTitleBar = true;
        SetTitleBar(AppTitleBar);
        var iconPath = Path.Combine(AppContext.BaseDirectory, "Assets", "AppIcon.ico");
        AppWindow.SetIcon(iconPath);
        TrayIcon.Icon = new System.Drawing.Icon(iconPath);
        AppWindow.Resize(new Windows.Graphics.SizeInt32(960, 680));
        if (AppWindow.Presenter is OverlappedPresenter presenter)
        {
            presenter.PreferredMinimumWidth = 420;
            presenter.PreferredMinimumHeight = 420;
        }
        AppWindow.Closing += OnClosing;

        AddKeyboardShortcuts();
        ViewModel.PropertyChanged += OnViewModelPropertyChanged;
        ViewModel.Stations.CollectionChanged += (_, _) => RebuildTrayMenu();
        RebuildTrayMenu();

        ViewModel.LoadCommand.Execute(null);
        NavigateTo(settings.Current.LastPage ?? "favorites");
    }

    public MainViewModel ViewModel { get; }

    [RelayCommand]
    private void ShowMainWindow() => App.Current.ShowMainWindow();

    [RelayCommand]
    private void ShowMiniPlayer() => App.Current.ShowMiniPlayer();

    public void ShowAndActivate()
    {
        AppWindow.Show();
        if (AppWindow.Presenter is OverlappedPresenter { State: OverlappedPresenterState.Minimized } presenter)
            presenter.Restore();
        Activate();
    }

    /// <summary>Hidden to the tray: tell once per session that the radio keeps playing.</summary>
    public void ShowTrayHintOnce()
    {
        if (_trayHintShown || !ViewModel.IsActive)
            return;
        _trayHintShown = true;
        TrayIcon.ShowNotification("Antenim Yok çalmaya devam ediyor",
            "Görev çubuğundaki simgeden yeniden açabilir veya çıkabilirsin.");
    }

    public void DisposeTrayIcon() => TrayIcon.Dispose();

    private void OnClosing(AppWindow sender, AppWindowClosingEventArgs args)
    {
        args.Cancel = true;
        App.Current.CloseWindow(this);
    }

    // ---------- Navigation ----------

    private void NavigateTo(string tag)
    {
        NavView.SelectedItem = NavView.MenuItems.Concat(NavView.FooterMenuItems)
            .OfType<NavigationViewItem>()
            .FirstOrDefault(i => (string)i.Tag == tag) ?? NavView.MenuItems[0];
    }

    private void OnNavigationSelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItem is not NavigationViewItem { Tag: string tag })
            return;

        var page = tag switch
        {
            "discover" => typeof(DiscoverPage),
            "settings" => typeof(SettingsPage),
            _ => typeof(FavoritesPage),
        };
        if (ContentFrame.CurrentSourcePageType != page)
            ContentFrame.Navigate(page, null, args.RecommendedNavigationTransitionInfo);
        _settings.Update(s => s with { LastPage = tag });
    }

    private void OnPaneToggleRequested(TitleBar sender, object args) => NavView.IsPaneOpen = !NavView.IsPaneOpen;

    // Typing a search while on another page jumps to Favorites, where the results are.
    private void OnSearchTextChanged(AutoSuggestBox sender, AutoSuggestBoxTextChangedEventArgs args)
    {
        if (args.Reason == AutoSuggestionBoxTextChangeReason.UserInput && ContentFrame.CurrentSourcePageType != typeof(FavoritesPage))
            NavigateTo("favorites");
    }

    // ---------- Keyboard ----------

    private void AddKeyboardShortcuts()
    {
        AddShortcut(VirtualKey.Space, VirtualKeyModifiers.None, () => ViewModel.TogglePlaybackCommand.Execute(null),
            skipWhenFocusOnControl: true);
        AddShortcut(VirtualKey.M, VirtualKeyModifiers.None, () => ViewModel.ToggleMuteCommand.Execute(null),
            skipWhenFocusOnControl: false);
        AddShortcut(VirtualKey.F, VirtualKeyModifiers.Control, () => SearchBox.Focus(FocusState.Keyboard));
        AddShortcut(VirtualKey.Up, VirtualKeyModifiers.Control, () => ViewModel.ChangeVolume(+1));
        AddShortcut(VirtualKey.Down, VirtualKeyModifiers.Control, () => ViewModel.ChangeVolume(-1));
        for (var n = 1; n <= 9; n++)
        {
            var index = n - 1;
            AddShortcut(VirtualKey.Number0 + n, VirtualKeyModifiers.Control, () => _ = ViewModel.PlayFavoriteAsync(index));
        }
    }

    /// <param name="skipWhenFocusOnControl">
    /// Let buttons/list items keep their own Space behaviour. Plain-letter shortcuts always yield to text input.
    /// </param>
    private void AddShortcut(VirtualKey key, VirtualKeyModifiers modifiers, Action action, bool skipWhenFocusOnControl = false)
    {
        var accelerator = new KeyboardAccelerator { Key = key, Modifiers = modifiers };
        accelerator.Invoked += (_, args) =>
        {
            var focused = FocusManager.GetFocusedElement(Root.XamlRoot);
            if (modifiers == VirtualKeyModifiers.None && focused is TextBox)
                return;
            if (skipWhenFocusOnControl && focused is ButtonBase or SelectorItem or ToggleSwitch)
                return;

            action();
            args.Handled = true;
        };
        Root.KeyboardAccelerators.Add(accelerator);
    }

    // ---------- Tray menu ----------

    private void OnViewModelPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(MainViewModel.State) or nameof(MainViewModel.CurrentStation))
            RebuildTrayMenu();
    }

    /// <summary>Favorites (playing one checked) + play/stop, show, mini player, exit.</summary>
    private void RebuildTrayMenu()
    {
        TrayMenu.Items.Clear();
        foreach (var item in ViewModel.Stations)
        {
            TrayMenu.Items.Add(new ToggleMenuFlyoutItem
            {
                Text = item.Name,
                IsChecked = item.IsPlaying,
                Command = ViewModel.PlayStationCommand,
                CommandParameter = item.Station,
            });
        }
        if (ViewModel.Stations.Count > 0)
            TrayMenu.Items.Add(new MenuFlyoutSeparator());

        TrayMenu.Items.Add(new MenuFlyoutItem { Text = ViewModel.PlayStopLabel, Command = ViewModel.TogglePlaybackCommand });
        TrayMenu.Items.Add(new MenuFlyoutItem { Text = "Göster", Command = ShowMainWindowCommand });
        TrayMenu.Items.Add(new MenuFlyoutItem { Text = "Mini oynatıcı", Command = ShowMiniPlayerCommand });
        TrayMenu.Items.Add(new MenuFlyoutSeparator());
        TrayMenu.Items.Add(new MenuFlyoutItem { Text = "Çıkış", Command = new RelayCommand(App.Current.ExitApp) });
    }
}
