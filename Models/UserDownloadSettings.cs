namespace YtDlpDownloader.Models;

public sealed class UserDownloadSettings
{
    public string SaveDirectory { get; init; } = "";
    public string MergeOutputFormat { get; init; } = "mp4";
    public string CookiesSource { get; init; } = "不使用";
    public string CookiesPath { get; init; } = "";
    public string Proxy { get; init; } = "";
    public bool DownloadSubtitles { get; init; }
    public bool DownloadAutoSubtitles { get; init; }
    public string SubtitleLanguages { get; init; } = "zh-Hans,zh-CN,en";
    public bool DownloadThumbnail { get; init; }
    public string FileConflictPolicy { get; init; } = "rename";
    public string RateLimit { get; init; } = "";
    public int RetryCount { get; init; } = 10;
    public int ConcurrentFragments { get; init; } = 5;
    public string ExtraArgumentsText { get; init; } = "";
}
