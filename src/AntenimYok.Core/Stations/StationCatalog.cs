using System.Net;
using System.Net.Http.Headers;
using Microsoft.Extensions.Logging;

namespace AntenimYok.Core.Stations;

/// <summary>
/// The curated station list (stations.json). Startup uses the last downloaded copy, or the embedded one
/// if nothing was downloaded yet; <see cref="RefreshAsync"/> fetches the shared online copy for next time.
/// </summary>
public sealed class StationCatalog(
    StationRepository repository,
    HttpClient http,
    Uri? remoteUrl,
    string cachePath,
    ILogger<StationCatalog> logger)
{
    /// <summary>%LOCALAPPDATA%\AntenimYok\stations.json</summary>
    public static string DefaultCachePath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AntenimYok", "stations.json");

    private string ETagPath => cachePath + ".etag";

    public async Task<IReadOnlyList<Station>> LoadAsync(CancellationToken cancellationToken = default)
    {
        if (File.Exists(cachePath))
        {
            try
            {
                await using var stream = File.OpenRead(cachePath);
                var cached = await repository.LoadAsync(stream, cancellationToken);
                if (cached.Count > 0)
                    return cached;
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Cached station list is unreadable; using the built-in one");
            }
        }
        return await repository.LoadEmbeddedAsync(cancellationToken);
    }

    /// <summary>Downloads the online list if it changed. Returns true when a new valid copy was saved.</summary>
    public async Task<bool> RefreshAsync(CancellationToken cancellationToken = default)
    {
        if (remoteUrl is null)
            return false;

        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, remoteUrl);
            if (File.Exists(ETagPath) && File.Exists(cachePath)
                && EntityTagHeaderValue.TryParse(await File.ReadAllTextAsync(ETagPath, cancellationToken), out var etag))
            {
                request.Headers.IfNoneMatch.Add(etag);
            }

            using var response = await http.SendAsync(request, cancellationToken);
            if (response.StatusCode == HttpStatusCode.NotModified)
                return false;
            response.EnsureSuccessStatusCode();

            var bytes = await response.Content.ReadAsByteArrayAsync(cancellationToken);
            // Never replace a working list with a broken one.
            var stations = await repository.LoadAsync(new MemoryStream(bytes), cancellationToken);
            if (stations.Count == 0)
                throw new InvalidDataException("Online station list has no stations.");

            Directory.CreateDirectory(Path.GetDirectoryName(cachePath)!);
            var temp = cachePath + ".tmp";
            await File.WriteAllBytesAsync(temp, bytes, cancellationToken);
            File.Move(temp, cachePath, overwrite: true);
            if (response.Headers.ETag is { } newTag)
                await File.WriteAllTextAsync(ETagPath, newTag.ToString(), cancellationToken);

            logger.LogInformation("Downloaded station list ({Count} stations)", stations.Count);
            return true;
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            logger.LogWarning(ex, "Could not refresh the station list from {Url}", remoteUrl);
            return false;
        }
    }
}
