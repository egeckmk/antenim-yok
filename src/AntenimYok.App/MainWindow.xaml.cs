using AntenimYok.App.ViewModels;
using AntenimYok.Core.Stations;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AntenimYok.App;

public sealed partial class MainWindow : Window
{
    public MainWindow(MainViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
        AppWindow.Resize(new Windows.Graphics.SizeInt32(960, 640));
        ViewModel.LoadCommand.Execute(null);
    }

    public MainViewModel ViewModel { get; }

    private void OnStationClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is Station station)
            ViewModel.PlayStationCommand.Execute(station);
    }
}
