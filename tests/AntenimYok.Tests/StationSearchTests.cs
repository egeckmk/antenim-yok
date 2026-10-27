using AntenimYok.Core.Stations;

namespace AntenimYok.Tests;

public class StationSearchTests
{
    [Theory]
    [InlineData("Power Türk", "power türk", true)]
    [InlineData("Power Türk", "turk", true)]
    [InlineData("Power Türk", "türk power", true)]
    [InlineData("Show Radyo", "RADYO", true)]
    [InlineData("İstanbul FM", "istanbul", true)]
    [InlineData("Radyo Fenomen", "  ", true)]
    [InlineData("Radyo Fenomen", null, true)]
    [InlineData("Metro FM", "kafa", false)]
    [InlineData("Power FM", "power türk", false)]
    public void Matches(string name, string? query, bool expected)
    {
        var station = new Station { Id = "x", Name = name };
        Assert.Equal(expected, StationSearch.Matches(station, query));
    }
}
