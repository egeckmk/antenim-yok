using AntenimYok.Core.Settings;
using Microsoft.Extensions.Logging.Abstractions;

namespace AntenimYok.Tests;

public sealed class SettingsStoreTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "AntenimYokTests", Guid.NewGuid().ToString("N"));

    private string SettingsPath => Path.Combine(_dir, "settings.json");

    private SettingsStore MakeStore(TimeSpan? delay = null) =>
        new(SettingsPath, NullLogger<SettingsStore>.Instance) { SaveDelay = delay ?? TimeSpan.FromHours(1) };

    [Fact]
    public void MissingFile_UsesDefaults()
    {
        var store = MakeStore();

        Assert.Null(store.Current.LastStationId);
        Assert.Equal(0.5, store.Current.Volume);
    }

    [Fact]
    public void Flush_PersistsAndReloads()
    {
        var store = MakeStore();
        store.Update(s => s with { LastStationId = "kafa-radyo", Volume = 0.8, IsMuted = true });
        store.Flush();

        var reloaded = MakeStore().Current;

        Assert.Equal("kafa-radyo", reloaded.LastStationId);
        Assert.Equal(0.8, reloaded.Volume);
        Assert.True(reloaded.IsMuted);
    }

    [Fact]
    public async Task Update_SavesAfterDelay()
    {
        var store = MakeStore(TimeSpan.FromMilliseconds(20));
        store.Update(s => s with { Volume = 0.3 });

        for (var i = 0; i < 100 && !File.Exists(SettingsPath); i++)
            await Task.Delay(20);

        Assert.Equal(0.3, MakeStore().Current.Volume);
    }

    [Fact]
    public void CorruptFile_UsesDefaults()
    {
        Directory.CreateDirectory(_dir);
        File.WriteAllText(SettingsPath, "{ not json");

        Assert.Equal(new AppSettings(), MakeStore().Current);
    }

    public void Dispose()
    {
        if (Directory.Exists(_dir))
            Directory.Delete(_dir, recursive: true);
    }
}
