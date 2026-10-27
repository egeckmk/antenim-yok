namespace AntenimYok.Core;

/// <summary>Writes a file via a temp file + rename, so a crash never leaves it half written.</summary>
public static class AtomicFile
{
    private const int Attempts = 5;

    /// <summary>
    /// Retries briefly on sharing violations: right after one write, antivirus or the indexer
    /// can hold the file for a moment, which used to drop the next save silently.
    /// </summary>
    public static void WriteAllText(string path, string contents)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var temp = path + ".tmp";
        for (var attempt = 1; ; attempt++)
        {
            try
            {
                File.WriteAllText(temp, contents);
                File.Move(temp, path, overwrite: true);
                return;
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException && attempt < Attempts)
            {
                Thread.Sleep(50 * attempt);
            }
        }
    }
}
