using System.Collections.ObjectModel;

namespace YtDlpDownloader.Models;

public sealed class VideoInfo
{
    public string Title { get; init; } = "";
    public string Author { get; init; } = "";
    public TimeSpan? Duration { get; init; }
    public string ThumbnailUrl { get; init; } = "";
    public string SourceUrl { get; init; } = "";
    public ObservableCollection<MediaFormat> Formats { get; } = [];
}
