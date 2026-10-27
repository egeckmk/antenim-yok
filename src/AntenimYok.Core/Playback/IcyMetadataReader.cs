using System.Runtime.CompilerServices;
using System.Text;

namespace AntenimYok.Core.Playback;

public interface IIcyMetadataReader
{
    /// <summary>Yields the stream's "now playing" title each time it changes. Ends if the stream has no metadata.</summary>
    IAsyncEnumerable<string> ReadTitlesAsync(Uri streamUrl, CancellationToken cancellationToken);
}

/// <summary>
/// Reads SHOUTcast/Icecast in-band metadata ("StreamTitle='Artist - Song';") over its own connection.
/// The audio itself is played by MediaPlayer, which does not expose these titles.
/// </summary>
public sealed class IcyMetadataReader(HttpClient http) : IIcyMetadataReader
{
    private static readonly Encoding Utf8Strict = new UTF8Encoding(false, throwOnInvalidBytes: true);

    static IcyMetadataReader() => Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);

    public async IAsyncEnumerable<string> ReadTitlesAsync(Uri streamUrl, [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, streamUrl);
        request.Headers.Add("Icy-MetaData", "1");
        using var response = await http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        response.EnsureSuccessStatusCode();

        if (!response.Headers.TryGetValues("icy-metaint", out var values)
            || !int.TryParse(values.FirstOrDefault(), out var metaInt) || metaInt <= 0)
        {
            yield break;
        }

        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        var audio = new byte[metaInt];
        var meta = new byte[255 * 16];
        string? last = null;

        while (true)
        {
            // Audio block (discarded), then one length byte (×16) and the metadata block.
            if (!await ReadExactlyOrEndAsync(stream, audio, metaInt, cancellationToken))
                yield break;
            var lengthByte = new byte[1];
            if (!await ReadExactlyOrEndAsync(stream, lengthByte, 1, cancellationToken))
                yield break;
            var length = lengthByte[0] * 16;
            if (length == 0)
                continue;
            if (!await ReadExactlyOrEndAsync(stream, meta, length, cancellationToken))
                yield break;

            var title = ParseStreamTitle(meta.AsSpan(0, length));
            if (title is not null && title != last)
            {
                last = title;
                yield return title;
            }
        }
    }

    /// <summary>Extracts StreamTitle from a metadata block; null if absent or blank.</summary>
    public static string? ParseStreamTitle(ReadOnlySpan<byte> block)
    {
        var text = Decode(block.TrimEnd((byte)0));
        const string start = "StreamTitle='";
        var from = text.IndexOf(start, StringComparison.Ordinal);
        if (from < 0)
            return null;
        from += start.Length;
        var to = text.IndexOf("';", from, StringComparison.Ordinal);
        if (to < 0)
            to = text.LastIndexOf('\'');
        if (to < from)
            return null;

        var title = text[from..to].Trim().Trim('-').Trim();
        return title.Length == 0 ? null : title;
    }

    // Most Turkish stations send UTF-8; older servers send Windows-1254.
    private static string Decode(ReadOnlySpan<byte> bytes)
    {
        try
        {
            return Utf8Strict.GetString(bytes);
        }
        catch (DecoderFallbackException)
        {
            return Encoding.GetEncoding(1254).GetString(bytes);
        }
    }

    private static async Task<bool> ReadExactlyOrEndAsync(Stream stream, byte[] buffer, int count, CancellationToken cancellationToken)
    {
        var read = 0;
        while (read < count)
        {
            var n = await stream.ReadAsync(buffer.AsMemory(read, count - read), cancellationToken);
            if (n == 0)
                return false;
            read += n;
        }
        return true;
    }
}
