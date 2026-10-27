using System.Text;
using AntenimYok.Core.Stations;
using Microsoft.Extensions.Logging;

namespace AntenimYok.Core.Playback;

public interface IStreamResolver
{
    /// <summary>Returns the URL the player should open (playlist files are expanded to their first entry).</summary>
    Task<Uri> ResolveAsync(StationStream stream, CancellationToken cancellationToken);
}

public sealed class StreamResolver(HttpClient http, ILogger<StreamResolver> logger) : IStreamResolver
{
    private const int MaxPlaylistBytes = 64 * 1024;

    public async Task<Uri> ResolveAsync(StationStream stream, CancellationToken cancellationToken)
    {
        var uri = new Uri(stream.Url);
        if (stream.Type == StreamType.Hls || PlaylistParser.DetectFormat(uri) is not { } format)
            return uri;

        using var response = await http.GetAsync(uri, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        response.EnsureSuccessStatusCode();

        // Read at most MaxPlaylistBytes: a misnamed URL could be an endless audio stream.
        await using var body = await response.Content.ReadAsStreamAsync(cancellationToken);
        var buffer = new byte[MaxPlaylistBytes];
        int total = 0, read;
        while (total < buffer.Length && (read = await body.ReadAsync(buffer.AsMemory(total), cancellationToken)) > 0)
            total += read;

        var content = Encoding.UTF8.GetString(buffer, 0, total);
        var entries = PlaylistParser.Parse(content, format, response.RequestMessage?.RequestUri ?? uri);
        if (entries.Count == 0)
            throw new InvalidDataException($"Playlist has no stream URLs: {uri}");

        logger.LogDebug("Resolved playlist {Playlist} to {Stream}", uri, entries[0]);
        return entries[0];
    }
}
