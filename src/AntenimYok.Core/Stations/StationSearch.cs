using System.Globalization;
using System.Text;

namespace AntenimYok.Core.Stations;

public static class StationSearch
{
    private static readonly CultureInfo Turkish = CultureInfo.GetCultureInfo("tr-TR");

    /// <summary>
    /// Case- and accent-insensitive name match ("turk" finds "Power Türk", "İSTANBUL" finds "istanbul").
    /// Every word of the query must appear. An empty query matches everything.
    /// </summary>
    public static bool Matches(Station station, string? query)
    {
        if (string.IsNullOrWhiteSpace(query))
            return true;

        var name = Fold(station.Name);
        return Fold(query)
            .Split(' ', StringSplitOptions.RemoveEmptyEntries)
            .All(word => name.Contains(word, StringComparison.Ordinal));
    }

    /// <summary>Lower case (Turkish rules), drop accents (ü→u, ş→s, ç→c, ğ→g, ö→o) and dotless ı→i.</summary>
    public static string Fold(string text)
    {
        var decomposed = text.ToLower(Turkish).Normalize(NormalizationForm.FormD);
        var sb = new StringBuilder(decomposed.Length);
        foreach (var c in decomposed)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark)
                sb.Append(c == 'ı' ? 'i' : c);
        }
        return sb.ToString();
    }
}
