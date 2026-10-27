using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Text;

namespace AntenimYok.App.Services;

/// <summary>
/// Gives the unpackaged app a fixed AppUserModelID plus a Start menu shortcut carrying it.
/// Windows needs both to launch the app by ID — e.g. when the media card in Quick Settings is clicked;
/// that launch is redirected to the running instance (see Program), which shows its window.
/// </summary>
internal static partial class AppIdentity
{
    public const string AppUserModelId = "Ege.AntenimYok";

    private static readonly string ShortcutPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.Programs), "Antenim Yok.lnk");

    /// <summary>Must run before any window or media session is created.</summary>
    public static void SetForProcess() => SetCurrentProcessExplicitAppUserModelID(AppUserModelId);

    /// <summary>Creates the Start menu shortcut, or repoints it if the app folder moved.</summary>
    public static void EnsureStartMenuShortcut()
    {
        var exePath = Environment.ProcessPath!;
        var link = (IShellLinkW)new CShellLink();

        if (File.Exists(ShortcutPath))
        {
            ((IPersistFile)link).Load(ShortcutPath, 0);
            var current = new StringBuilder(260);
            link.GetPath(current, current.Capacity, IntPtr.Zero, 0);
            if (string.Equals(current.ToString(), exePath, StringComparison.OrdinalIgnoreCase))
                return;
            link = (IShellLinkW)new CShellLink();
        }

        link.SetPath(exePath);
        link.SetWorkingDirectory(Path.GetDirectoryName(exePath)!);
        link.SetDescription("Reklamsız radyo");

        var key = new PropertyKey(new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), 5); // PKEY_AppUserModel_ID
        var value = PropVariant.FromString(AppUserModelId);
        try
        {
            var store = (IPropertyStore)link;
            store.SetValue(ref key, ref value);
            store.Commit();
        }
        finally
        {
            PropVariantClear(ref value);
        }

        Directory.CreateDirectory(Path.GetDirectoryName(ShortcutPath)!);
        ((IPersistFile)link).Save(ShortcutPath, true);
    }

    [LibraryImport("shell32.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial int SetCurrentProcessExplicitAppUserModelID(string appId);

    [DllImport("ole32.dll")]
    private static extern int PropVariantClear(ref PropVariant pvar);

    [ComImport, Guid("00021401-0000-0000-C000-000000000046")]
    private class CShellLink;

    [ComImport, Guid("000214F9-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IShellLinkW
    {
        void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszFile, int cch, IntPtr pfd, uint fFlags);
        void GetIDList(out IntPtr ppidl);
        void SetIDList(IntPtr pidl);
        void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszName, int cch);
        void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);
        void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszDir, int cch);
        void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);
        void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszArgs, int cch);
        void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
        void GetHotkey(out short pwHotkey);
        void SetHotkey(short wHotkey);
        void GetShowCmd(out int piShowCmd);
        void SetShowCmd(int iShowCmd);
        void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszIconPath, int cch, out int piIcon);
        void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);
        void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPathRel, uint dwReserved);
        void Resolve(IntPtr hwnd, uint fFlags);
        void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
    }

    [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IPropertyStore
    {
        void GetCount(out uint cProps);
        void GetAt(uint iProp, out PropertyKey pkey);
        void GetValue(ref PropertyKey key, out PropVariant pv);
        void SetValue(ref PropertyKey key, ref PropVariant pv);
        void Commit();
    }

    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    private readonly struct PropertyKey(Guid formatId, uint propertyId)
    {
        public readonly Guid FormatId = formatId;
        public readonly uint PropertyId = propertyId;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct PropVariant
    {
        private const ushort VtLpwstr = 31;

        [FieldOffset(0)] private ushort _vt;
        [FieldOffset(8)] private IntPtr _pointer;

        public static PropVariant FromString(string value) =>
            new() { _vt = VtLpwstr, _pointer = Marshal.StringToCoTaskMemUni(value) };
    }
}
