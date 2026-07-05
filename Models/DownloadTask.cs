namespace YtDlpDownloader.Models;

public sealed class DownloadTask
{
    public required string Url { get; init; }
    public required string OutputTemplate { get; init; }
    public required MediaFormat Format { get; init; }
    public string? FfmpegPath { get; init; }
    public required DownloadOptions Options { get; init; }
}
