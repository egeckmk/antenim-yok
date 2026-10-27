using System;
using System.Collections.Concurrent;
using System.IO;
using System.Net.Http;
using System.Runtime.InteropServices.WindowsRuntime;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using AntenimYok.Core.Stations;
using Microsoft.Extensions.Logging;
using Windows.Graphics.Imaging;
using Windows.Storage.Streams;

namespace AntenimYok.App.Services;

/// <summary>
/// Downloads station logos once and keeps them as PNG under %LOCALAPPDATA%\AntenimYok\logos.
/// Re-encoding to PNG lets ICO/WebP/huge images work everywhere (window, media overlay).
/// </summary>
public sealed class LogoCache(HttpClient http, ILogger<LogoCache> logger)
{
    private const uint MaxSize = 256;

    private readonly string _directory = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AntenimYok", "logos");

    private readonly ConcurrentDictionary<string, Task<string?>> _loads = new();

    /// <summary>Local PNG path of the station logo, or null if it has none or it could not be loaded.</summary>
    public Task<string?> GetPathAsync(Station station) =>
        string.IsNullOrEmpty(station.Logo)
            ? Task.FromResult<string?>(null)
            : _loads.GetOrAdd(station.Id, _ => LoadAsync(station.Id, station.Logo));

    private async Task<string?> LoadAsync(string stationId, string url)
    {
        // The URL hash in the name means an edited logo URL in stations.json is fetched again.
        var path = Path.Combine(_directory, $"{stationId}-{Hash(url)}.png");
        if (File.Exists(path))
            return path;

        try
        {
            var bytes = await http.GetByteArrayAsync(url).ConfigureAwait(false);
            Directory.CreateDirectory(_directory);
            await ConvertToPngAsync(bytes, path).ConfigureAwait(false);

            foreach (var old in Directory.EnumerateFiles(_directory, $"{stationId}-*.png"))
            {
                if (!string.Equals(old, path, StringComparison.OrdinalIgnoreCase))
                    File.Delete(old);
            }
            return path;
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Could not load logo for {Station} from {Url}", stationId, url);
            _loads.TryRemove(stationId, out _); // Try again next time.
            return null;
        }
    }

    private static async Task ConvertToPngAsync(byte[] bytes, string path)
    {
        using var input = new InMemoryRandomAccessStream();
        await input.WriteAsync(bytes.AsBuffer());
        input.Seek(0);
        var decoder = await BitmapDecoder.CreateAsync(input);

        // ICO files hold several sizes; take the largest.
        var frame = await decoder.GetFrameAsync(0);
        for (uint i = 1; i < decoder.FrameCount; i++)
        {
            var candidate = await decoder.GetFrameAsync(i);
            if (candidate.OrientedPixelWidth > frame.OrientedPixelWidth)
                frame = candidate;
        }

        var scale = Math.Min(1.0, (double)MaxSize / Math.Max(frame.OrientedPixelWidth, frame.OrientedPixelHeight));
        var width = Math.Max(1u, (uint)Math.Round(frame.OrientedPixelWidth * scale));
        var height = Math.Max(1u, (uint)Math.Round(frame.OrientedPixelHeight * scale));
        var transform = new BitmapTransform
        {
            ScaledWidth = width,
            ScaledHeight = height,
            InterpolationMode = BitmapInterpolationMode.Fant,
        };
        var pixels = await frame.GetPixelDataAsync(
            BitmapPixelFormat.Bgra8, BitmapAlphaMode.Premultiplied, transform,
            ExifOrientationMode.RespectExifOrientation, ColorManagementMode.ColorManageToSRgb);

        var temp = path + ".tmp";
        using (var output = File.Create(temp))
        {
            var encoder = await BitmapEncoder.CreateAsync(BitmapEncoder.PngEncoderId, output.AsRandomAccessStream());
            encoder.SetPixelData(BitmapPixelFormat.Bgra8, BitmapAlphaMode.Premultiplied, width, height, 96, 96,
                pixels.DetachPixelData());
            await encoder.FlushAsync();
        }
        File.Move(temp, path, overwrite: true);
    }

    private static string Hash(string url) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(url)))[..12].ToLowerInvariant();
}
