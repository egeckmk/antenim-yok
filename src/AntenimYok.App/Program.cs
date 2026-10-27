using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using AntenimYok.App.Services;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.Windows.AppLifecycle;
using Velopack;

namespace AntenimYok.App;

/// <summary>Custom entry point (DISABLE_XAML_GENERATED_MAIN) so a second launch hands over to the running instance.</summary>
public static partial class Program
{
    private const string InstanceKey = "main";

    [STAThread]
    private static int Main(string[] args)
    {
        // Velopack first: during install/update/uninstall it runs the hooks below and exits right here.
        VelopackApp.Build()
            .SetAppUserModelId(AppIdentity.AppUserModelId)
            .OnBeforeUninstallFastCallback(_ =>
            {
                AppIdentity.RemoveStartMenuShortcut();
                new StartupService().IsEnabled = false;
            })
            .Run();

        WinRT.ComWrappersSupport.InitializeComWrappers();
        AppIdentity.SetForProcess();

        if (RedirectToRunningInstance())
            return 0;

        Task.Run(() =>
        {
            try
            {
                AppIdentity.EnsureStartMenuShortcut();
            }
            catch (Exception ex)
            {
                // Only costs "open from the media card"; never block startup.
                Debug.WriteLine($"Start menu shortcut failed: {ex}");
            }
        });

        Application.Start(p =>
        {
            var context = new DispatcherQueueSynchronizationContext(DispatcherQueue.GetForCurrentThread());
            SynchronizationContext.SetSynchronizationContext(context);
            _ = new App();
        });
        return 0;
    }

    private static bool RedirectToRunningInstance()
    {
        var mainInstance = AppInstance.FindOrRegisterForKey(InstanceKey);
        if (mainInstance.IsCurrent)
            return false;

        // Let the running instance bring its window to the front.
        AllowSetForegroundWindow((uint)mainInstance.ProcessId);
        var activation = AppInstance.GetCurrent().GetActivatedEventArgs();
        // Off the STA thread: blocking it while the redirect runs could deadlock.
        Task.Run(() => mainInstance.RedirectActivationToAsync(activation).AsTask()).Wait();
        return true;
    }

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool AllowSetForegroundWindow(uint processId);
}
