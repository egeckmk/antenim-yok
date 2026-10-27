using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Velopack;
using Velopack.Sources;

namespace AntenimYok.App.Services;

public enum UpdateStatus
{
    /// <summary>Running from a build folder, not installed with Setup.exe: no updates.</summary>
    NotInstalled,
    Idle,
    Checking,
    UpToDate,
    Downloading,
    /// <summary>Downloaded; applied on restart (or automatically on the next start).</summary>
    ReadyToRestart,
    Failed,
}

/// <summary>
/// Updates from GitHub Releases (Velopack). Checks shortly after start and then every few hours,
/// downloads in the background; the update is applied on "restart" or on the next start.
/// </summary>
public sealed class UpdateService(ILogger<UpdateService> logger)
{
    public const string RepositoryUrl = "https://github.com/egeckmk/antenim-yok";

    private static readonly TimeSpan FirstCheckDelay = TimeSpan.FromSeconds(30);
    private static readonly TimeSpan CheckInterval = TimeSpan.FromHours(6);

    private readonly UpdateManager _manager = new(new GithubSource(RepositoryUrl, accessToken: null, prerelease: false));
    private readonly SemaphoreSlim _gate = new(1, 1);
    private UpdateInfo? _pending;
    private Timer? _timer;

    public UpdateStatus Status { get; private set; } = UpdateStatus.Idle;

    /// <summary>Version being downloaded / ready, e.g. "1.0.1".</summary>
    public string? NewVersion { get; private set; }

    /// <summary>Raised on a background thread.</summary>
    public event EventHandler? StatusChanged;

    public bool IsInstalled => _manager.IsInstalled;

    public void StartBackgroundChecks()
    {
        if (!IsInstalled)
        {
            SetStatus(UpdateStatus.NotInstalled);
            return;
        }
        _timer = new Timer(_ => _ = CheckAsync(), null, FirstCheckDelay, CheckInterval);
    }

    /// <summary>Checks GitHub and downloads a newer release if there is one.</summary>
    public async Task CheckAsync()
    {
        if (!IsInstalled || Status == UpdateStatus.ReadyToRestart || !await _gate.WaitAsync(0))
            return;
        try
        {
            SetStatus(UpdateStatus.Checking);
            var update = await _manager.CheckForUpdatesAsync();
            if (update is null)
            {
                SetStatus(UpdateStatus.UpToDate);
                return;
            }

            NewVersion = update.TargetFullRelease.Version.ToString();
            SetStatus(UpdateStatus.Downloading);
            await _manager.DownloadUpdatesAsync(update);
            _pending = update;
            logger.LogInformation("Update {Version} downloaded", NewVersion);
            SetStatus(UpdateStatus.ReadyToRestart);
        }
        catch (Exception ex)
        {
            // Offline, GitHub unreachable or rate limited: try again at the next interval.
            logger.LogWarning(ex, "Update check failed");
            SetStatus(UpdateStatus.Failed);
        }
        finally
        {
            _gate.Release();
        }
    }

    /// <summary>Closes the app, installs the downloaded release and starts it again.</summary>
    public void RestartAndApply()
    {
        if (_pending is not null)
            _manager.ApplyUpdatesAndRestart(_pending);
    }

    private void SetStatus(UpdateStatus status)
    {
        Status = status;
        StatusChanged?.Invoke(this, EventArgs.Empty);
    }
}
