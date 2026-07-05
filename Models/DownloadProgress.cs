namespace YtDlpDownloader.Models;

public sealed class DownloadProgress
{
    public double? Percentage { get; init; }
    public string Speed { get; init; } = "";
    public string Eta { get; init; } = "";
    public string Downloaded { get; init; } = "";
    public string Stage { get; init; } = "";
    public string Message { get; init; } = "";
    public bool ShowInLog { get; init; } = true;
}
