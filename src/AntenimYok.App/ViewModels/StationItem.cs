using AntenimYok.Core.Stations;
using CommunityToolkit.Mvvm.ComponentModel;
using Microsoft.UI.Xaml.Media;

namespace AntenimYok.App.ViewModels;

/// <summary>
/// A station as shown anywhere in the UI (favorites, Discover, now playing). One instance per station id,
/// so its logo, playing and favorite state are shared between pages.
/// </summary>
public sealed partial class StationItem(Station station) : ObservableObject
{
    public Station Station { get; } = station;

    public string Name => Station.Name;
    public string Initials => Station.Initials;

    /// <summary>White logo: needs a dark plate in the light theme.</summary>
    public bool LogoOnDarkOnly => Station.LogoOnDarkOnly;

    /// <summary>Second line in lists (Discover: genres, codec).</summary>
    public string Subtitle { get; set; } = string.Empty;

    /// <summary>Logo download already started (it is fetched once, when first shown).</summary>
    public bool LogoRequested { get; set; }

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasLogo))]
    public partial ImageSource? Logo { get; set; }

    public bool HasLogo => Logo is not null;

    /// <summary>This station is connecting, playing or reconnecting.</summary>
    [ObservableProperty]
    public partial bool IsPlaying { get; set; }

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(FavoriteGlyph), nameof(FavoriteLabel))]
    public partial bool IsFavorite { get; set; }

    public string FavoriteGlyph => char.ConvertFromUtf32(IsFavorite ? 0xE735 : 0xE734); // Filled / outline star
    public string FavoriteLabel => IsFavorite ? "Favorilerden çıkar" : "Favorilere ekle";

    // List items use ToString for their accessible name (Narrator).
    public override string ToString() => Name;
}
