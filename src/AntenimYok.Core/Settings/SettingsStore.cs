using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;

namespace AntenimYok.Core.Settings;

/// <summary>
/// Keeps <see cref="AppSettings"/> in a JSON file. Updates are written after a short delay
/// so dragging the volume slider does not hit the disk on every tick.
/// </summary>
public sealed class SettingsStore
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };

    private readonly string _path;
    private readonly ILogger<SettingsStore> _logger;
    private readonly Lock _gate = new();
    private readonly Lock _ioGate = new();
    private CancellationTokenSource? _pendingSave;

    public SettingsStore(string path, ILogger<SettingsStore> logger)
    {
        _path = path;
        _logger = logger;
        Current = Load();
    }

    /// <summary>%LOCALAPPDATA%\AntenimYok\settings.json</summary>
    public static string DefaultPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AntenimYok", "settings.json");

    public TimeSpan SaveDelay { get; init; } = TimeSpan.FromMilliseconds(500);

    public AppSettings Current { get; private set; }

    public void Update(Func<AppSettings, AppSettings> change)
    {
        CancellationTokenSource cts;
        lock (_gate)
        {
            var next = change(Current);
            if (next == Current)
                return;
            Current = next;
            _pendingSave?.Cancel();
            _pendingSave = cts = new CancellationTokenSource();
        }
        _ = SaveLaterAsync(cts.Token);
    }

    /// <summary>Writes pending changes now (call on exit).</summary>
    public void Flush()
    {
        lock (_gate)
        {
            if (_pendingSave is null)
                return;
            _pendingSave.Cancel();
            _pendingSave = null;
        }
        Save();
    }

    private async Task SaveLaterAsync(CancellationToken token)
    {
        try
        {
            await Task.Delay(SaveDelay, token);
            lock (_gate)
            {
                if (token.IsCancellationRequested)
                    return;
                _pendingSave = null;
            }
            Save();
        }
        catch (OperationCanceledException)
        {
        }
    }

    private AppSettings Load()
    {
        try
        {
            if (File.Exists(_path))
                return JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(_path), JsonOptions) ?? new AppSettings();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not read settings from {Path}; using defaults", _path);
        }
        return new AppSettings();
    }

    private void Save()
    {
        try
        {
            lock (_ioGate)
            {
                AppSettings snapshot;
                lock (_gate)
                    snapshot = Current;

                Directory.CreateDirectory(Path.GetDirectoryName(_path)!);
                var temp = _path + ".tmp";
                File.WriteAllText(temp, JsonSerializer.Serialize(snapshot, JsonOptions));
                File.Move(temp, _path, overwrite: true);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not save settings to {Path}", _path);
        }
    }
}
