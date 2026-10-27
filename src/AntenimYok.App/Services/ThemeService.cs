using System.Collections.Generic;
using AntenimYok.Core.Settings;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;

namespace AntenimYok.App.Services;

/// <summary>Applies the light/dark/system choice to every app window (content + caption buttons).</summary>
public sealed class ThemeService(SettingsStore settings)
{
    private readonly List<Window> _windows = [];

    public void Register(Window window)
    {
        _windows.Add(window);
        Apply(window, settings.Current.Theme);
    }

    public void Apply(AppTheme theme)
    {
        foreach (var window in _windows)
            Apply(window, theme);
    }

    private static void Apply(Window window, AppTheme theme)
    {
        if (window.Content is FrameworkElement root)
        {
            root.RequestedTheme = theme switch
            {
                AppTheme.Light => ElementTheme.Light,
                AppTheme.Dark => ElementTheme.Dark,
                _ => ElementTheme.Default,
            };
        }

        window.AppWindow.TitleBar.PreferredTheme = theme switch
        {
            AppTheme.Light => TitleBarTheme.Light,
            AppTheme.Dark => TitleBarTheme.Dark,
            _ => TitleBarTheme.UseDefaultAppMode,
        };
    }
}
