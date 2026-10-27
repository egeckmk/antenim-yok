namespace AntenimYok.Core.Settings;

public sealed record AppSettings
{
    public string? LastStationId { get; init; }

    /// <summary>0.0 – 1.0</summary>
    public double Volume { get; init; } = 0.5;

    public bool IsMuted { get; init; }
}
