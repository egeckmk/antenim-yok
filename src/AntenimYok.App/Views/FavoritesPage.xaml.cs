using AntenimYok.App.ViewModels;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AntenimYok.App.Views;

public sealed partial class FavoritesPage : Page
{
    public FavoritesPage()
    {
        ViewModel = App.Current.Services.GetRequiredService<MainViewModel>();
        InitializeComponent();
    }

    public MainViewModel ViewModel { get; }

    private void OnStationClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is StationItem item)
            ViewModel.PlayStationCommand.Execute(item.Station);
    }

    private void OnClearSearch(object sender, RoutedEventArgs e) => ViewModel.SearchText = string.Empty;
}
