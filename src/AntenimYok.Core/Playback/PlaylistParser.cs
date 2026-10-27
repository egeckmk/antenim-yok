namespace AntenimYok.Core.Playback;

public enum PlaylistFormat
{
    Pls,
    M3u,
}

/// <summary>Extracts stream URLs from .pls / .m3u playlist files.</summary>
public static class PlaylistParser
{
    /// <summary>Detects a playlist by file extension. HLS (.m3u8) is not a playlist here; the player handles it.</summary>
    public static PlaylistFormat? DetectFormat(Uri uri)
    {
        var path = uri.AbsolutePath;
        if (path.EndsWith(".pls", StringComparison.OrdinalIgnoreCase))
            return PlaylistFormat.Pls;
        if (path.EndsWith(".m3u", StringComparison.OrdinalIgnoreCase))
            return PlaylistFormat.M3u;
        return null;
    }

    public static IReadOnlyList<Uri> Parse(string content, PlaylistFormat format, Uri baseUri)
    {
        var urls = new List<Uri>();
        foreach (var rawLine in content.Split('\n'))
        {
            var line = rawLine.Trim();
            if (line.Length == 0)
                continue;

            var candidate = format switch
            {
                PlaylistFormat.Pls => ParsePlsLine(line),
                PlaylistFormat.M3u => line.StartsWith('#') ? null : line,
                _ => null,
            };

            if (candidate is not null && Uri.TryCreate(baseUri, candidate, out var uri)
                && (uri.Scheme == Uri.UriSchemeHttp || uri.Scheme == Uri.UriSchemeHttps))
            {
                urls.Add(uri);
            }
        }
        return urls;
    }

    // "File1=http://host/stream"
    private static string? ParsePlsLine(string line)
    {
        if (!line.StartsWith("File", StringComparison.OrdinalIgnoreCase))
            return null;
        var eq = line.IndexOf('=');
        return eq > 0 ? line[(eq + 1)..].Trim() : null;
    }
}
