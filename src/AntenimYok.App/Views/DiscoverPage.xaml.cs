using AntenimYok.App.ViewModels;
using AntenimYok.Core.Discovery;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;

namespace AntenimYok.App.Views;

public sealed partial class DiscoverPage : Page
{
    private readonly MainViewModel _main;

    public DiscoverPage()
    {
        ViewModel = App.Current.Services.GetRequiredService<DiscoverViewModel>();
        _main = App.Current.Services.GetRequiredService<MainViewModel>();
        InitializeComponent();
        GenreList.SelectedItem = ViewModel.SelectedGenre;
    }

    public DiscoverViewModel ViewModel { get; }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        _ = ViewModel.EnsureLoadedAsync();
    }

    private void OnGenreSelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (GenreList.SelectedItem is Genre genre)
            ViewModel.SelectedGenre = genre;
    }

    // Logos are fetched only for rows that are actually shown (the list has ~800 stations).
    private void OnResultContainerContentChanging(ListViewBase sender, ContainerContentChangingEventArgs args)
    {
        if (!args.InRecycleQueue && args.Item is StationItem item)
            ViewModel.EnsureLogo(item);
    }

    private void OnStationClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is StationItem item)
            _main.PlayStationCommand.Execute(item.Station);
    }

    private void OnToggleFavorite(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: StationItem item })
            _main.ToggleFavoriteCommand.Execute(item);
    }
}
