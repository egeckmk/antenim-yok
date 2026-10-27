namespace AntenimYok.Core.Settings;

public sealed record AppSettings
{
    public string? LastStationId { get; init; }

    /// <summary>0.0 – 1.0</summary>
    public double Volume { get; init; } = 0.5;

    public bool IsMuted { get; init; }

    public AppTheme Theme { get; init; } = AppTheme.System;

    /// <summary>Closing the window hides it to the tray and keeps playing (otherwise the app quits).</summary>
    public bool CloseToTray { get; init; } = true;

    /// <summary>Navigation tag of the last open section.</summary>
    public string? LastPage { get; init; }

    public WindowPosition? MiniPlayerPosition { get; init; }
}

public enum AppTheme
{
    System,
    Light,
    Dark,
}

public sealed record WindowPosition(int X, int Y);
