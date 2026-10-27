using AntenimYok.Core.Stations;
using CommunityToolkit.Mvvm.ComponentModel;
using Microsoft.UI.Xaml.Media;

namespace AntenimYok.App.ViewModels;

/// <summary>A station in the list plus its (asynchronously loaded) logo.</summary>
public sealed partial class StationItem(Station station) : ObservableObject
{
    public Station Station { get; } = station;

    public string Name => Station.Name;
    public string Initials => Station.Initials;

    /// <summary>White logo: needs a dark plate in the light theme.</summary>
    public bool LogoOnDarkOnly => Station.LogoOnDarkOnly;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasLogo))]
    public partial ImageSource? Logo { get; set; }

    public bool HasLogo => Logo is not null;

    // List items use ToString for their accessible name (Narrator).
    public override string ToString() => Name;
}
