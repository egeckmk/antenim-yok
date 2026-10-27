using AntenimYok.App.ViewModels;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AntenimYok.App.Controls;

public sealed partial class StationLogo : UserControl
{
    public static readonly DependencyProperty ItemProperty = DependencyProperty.Register(
        nameof(Item), typeof(StationItem), typeof(StationLogo), new PropertyMetadata(null));

    public static readonly DependencyProperty InitialsStyleProperty = DependencyProperty.Register(
        nameof(InitialsStyle), typeof(Style), typeof(StationLogo), new PropertyMetadata(null));

    public StationLogo()
    {
        InitializeComponent();
    }

    public StationItem? Item
    {
        get => (StationItem?)GetValue(ItemProperty);
        set => SetValue(ItemProperty, value);
    }

    public Style? InitialsStyle
    {
        get => (Style?)GetValue(InitialsStyleProperty);
        set => SetValue(InitialsStyleProperty, value);
    }

    public static Visibility IsVisible(bool a, bool b) => a && b ? Visibility.Visible : Visibility.Collapsed;

    public static Visibility IsCollapsed(bool value) => value ? Visibility.Collapsed : Visibility.Visible;
}
