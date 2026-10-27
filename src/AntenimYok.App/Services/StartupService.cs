using System;
using Microsoft.Win32;

namespace AntenimYok.App.Services;

/// <summary>
/// "Start with Windows" for the unpackaged app: a value under HKCU\…\Run (no admin needed).
/// The registry is the source of truth, so the setting also reflects changes made in Task Manager.
/// </summary>
public sealed class StartupService
{
    /// <summary>Command-line flag: started by Windows at sign-in → stay in the tray, no window.</summary>
    public const string BackgroundArgument = "--background";

    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "AntenimYok";

    private static string Command => $"\"{Environment.ProcessPath}\" {BackgroundArgument}";

    public bool IsEnabled
    {
        get
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath);
            return key?.GetValue(ValueName) is string;
        }
        set
        {
            using var key = Registry.CurrentUser.CreateSubKey(RunKeyPath);
            if (value)
                key.SetValue(ValueName, Command);
            else
                key.DeleteValue(ValueName, throwOnMissingValue: false);
        }
    }

    /// <summary>After an update into another folder, point the entry at this exe again.</summary>
    public void RefreshPath()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, writable: true);
        if (key?.GetValue(ValueName) is string current && current != Command)
            key.SetValue(ValueName, Command);
    }

    public static bool WasStartedInBackground() =>
        Array.Exists(Environment.GetCommandLineArgs(), a => string.Equals(a, BackgroundArgument, StringComparison.OrdinalIgnoreCase));
}
