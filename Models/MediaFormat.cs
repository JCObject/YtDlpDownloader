namespace YtDlpDownloader.Models;

public sealed class MediaFormat
{
    public string FormatId { get; init; } = "";
    public string DisplayName { get; init; } = "";
    public string FormatSelector { get; init; } = "";
    public string Extension { get; init; } = "";
    public string VideoCodec { get; init; } = "";
    public string AudioCodec { get; init; } = "";
    public string Resolution { get; init; } = "";
    public double? Fps { get; init; }
    public long? FileSizeBytes { get; init; }
    public bool IsRecommended { get; init; }
    public bool IsAudioOnly { get; init; }
    public bool RequiresFfmpeg { get; init; }
    public bool IsSimpleOption { get; init; }

    public string FileSizeText => FileSizeBytes is null ? "未知" : FormatBytes(FileSizeBytes.Value);
    public string Kind => IsAudioOnly ? "音频" : RequiresFfmpeg ? "需合并" : "单文件";

    public string Summary
    {
        get
        {
            var codecs = IsAudioOnly ? AudioCodec : $"{VideoCodec} / {AudioCodec}";
            return $"{Kind}  {Resolution}  {Extension}  {codecs}  {FileSizeText}";
        }
    }

    private static string FormatBytes(long bytes)
    {
        string[] units = ["B", "KB", "MB", "GB"];
        double value = bytes;
        var unitIndex = 0;

        while (value >= 1024 && unitIndex < units.Length - 1)
        {
            value /= 1024;
            unitIndex++;
        }

        return $"{value:0.#} {units[unitIndex]}";
    }
}
