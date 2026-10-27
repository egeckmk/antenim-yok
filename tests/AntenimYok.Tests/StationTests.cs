using AntenimYok.Core.Stations;

namespace AntenimYok.Tests;

public class StationTests
{
    [Theory]
    [InlineData("Kafa Radyo", "KR")]
    [InlineData("Virgin Radio Türkiye", "VR")]
    [InlineData("Metro FM", "MF")]
    [InlineData("idil", "İ")]
    public void Initials_UsesFirstTwoWords(string name, string expected)
    {
        var station = new Station { Id = "x", Name = name };
        Assert.Equal(expected, station.Initials);
    }
}
