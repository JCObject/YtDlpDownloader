using System.Collections.ObjectModel;
using System.IO;
using System.Text.Json;
using YtDlpDownloader.Infrastructure;
using YtDlpDownloader.Models;

namespace YtDlpDownloader.Services;

public sealed class YtDlpService
{
    private readonly ProcessRunner _processRunner;
    private readonly ToolPathService _toolPathService;

    public YtDlpService(ProcessRunner processRunner, ToolPathService toolPathService)
    {
        _processRunner = processRunner;
        _toolPathService = toolPathService;
    }

    public async Task<VideoInfo> GetVideoInfoAsync(
        string url,
        string cookiesSource,
        string cookiesPath,
        string proxy,
        Action<string>? onOutput,
        CancellationToken cancellationToken)
    {
        var preparedUrl = YtDlpUrlHelper.Normalize(url);
        var arguments = new List<string> { "--no-warnings", "--no-playlist", "--dump-single-json" };
        _toolPathService.AddCommonArguments(arguments);
        YtDlpUrlHelper.AddSiteArguments(arguments, preparedUrl);
        AddUserNetworkArguments(arguments, cookiesSource, cookiesPath, proxy);
        arguments.Add(preparedUrl);
        var result = await _processRunner.RunAsync(_toolPathService.YtDlpPath, arguments, onOutput, cancellationToken);

        if (result.ExitCode != 0)
        {
            throw new InvalidOperationException(CreateToolError("解析失败", result.Error));
        }

        using var document = JsonDocument.Parse(result.Output);
        var root = document.RootElement;
        if (!HasDownloadableFormats(root))
        {
            throw new InvalidOperationException("解析失败：这不是可下载的视频页面，请粘贴完整的视频网址。");
        }

        var formats = BuildFormats(root);

        return new VideoInfo
        {
            Title = ReadString(root, "title"),
            Author = ReadString(root, "uploader", "channel", "creator"),
            Duration = ReadDouble(root, "duration") is { } seconds ? TimeSpan.FromSeconds(seconds) : null,
            ThumbnailUrl = ReadThumbnail(root),
            SourceUrl = ReadString(root, "webpage_url", "original_url"),
            Formats = { }
        }.WithFormats(formats);
    }

    private static bool HasDownloadableFormats(JsonElement root)
    {
        if (!root.TryGetProperty("formats", out var formatArray) || formatArray.ValueKind != JsonValueKind.Array)
        {
            return false;
        }

        return formatArray
            .EnumerateArray()
            .Any(format => !string.IsNullOrWhiteSpace(ReadString(format, "format_id")));
    }

    private static ObservableCollection<MediaFormat> BuildFormats(JsonElement root)
    {
        var formats = new List<MediaFormat>
        {
            new()
            {
                FormatId = "recommended-best",
                DisplayName = "最佳画质（推荐）",
                FormatSelector = "bestvideo+bestaudio/best",
                Extension = "自动",
                VideoCodec = "自动",
                AudioCodec = "自动",
                Resolution = "最高可用",
                IsRecommended = true,
                IsSimpleOption = true,
                RequiresFfmpeg = true
            },
            new()
            {
                FormatId = "recommended-1080p",
                DisplayName = "1080p",
                FormatSelector = "bv*[height<=1080]+ba/b[height<=1080]/best[height<=1080]",
                Extension = "自动",
                VideoCodec = "自动",
                AudioCodec = "自动",
                Resolution = "1080p 或以下",
                IsRecommended = true,
                IsSimpleOption = true,
                RequiresFfmpeg = true
            },
            new()
            {
                FormatId = "recommended-720p",
                DisplayName = "720p",
                FormatSelector = "bv*[height<=720]+ba/b[height<=720]/best[height<=720]",
                Extension = "自动",
                VideoCodec = "自动",
                AudioCodec = "自动",
                Resolution = "720p 或以下",
                IsRecommended = true,
                IsSimpleOption = true,
                RequiresFfmpeg = true
            },
            new()
            {
                FormatId = "recommended-single-mp4",
                DisplayName = "单文件 MP4",
                FormatSelector = "best[ext=mp4][vcodec!=none][acodec!=none]/best[vcodec!=none][acodec!=none]",
                Extension = "mp4",
                VideoCodec = "自动",
                AudioCodec = "自动",
                Resolution = "自动",
                IsRecommended = true,
                IsSimpleOption = true
            },
            new()
            {
                FormatId = "recommended-audio",
                DisplayName = "仅音频",
                FormatSelector = "bestaudio/best",
                Extension = "自动",
                VideoCodec = "none",
                AudioCodec = "最佳音频",
                Resolution = "音频",
                IsRecommended = true,
                IsSimpleOption = true,
                IsAudioOnly = true
            }
        };

        if (root.TryGetProperty("formats", out var formatArray) && formatArray.ValueKind == JsonValueKind.Array)
        {
            formats.AddRange(formatArray
                .EnumerateArray()
                .Select(CreateFormat)
                .Where(format => !string.IsNullOrWhiteSpace(format.FormatId))
                .OrderByDescending(format => ParseHeight(format.Resolution))
                .ThenByDescending(format => format.FileSizeBytes ?? 0));
        }

        return new ObservableCollection<MediaFormat>(formats);
    }

    private static MediaFormat CreateFormat(JsonElement element)
    {
        var formatId = ReadString(element, "format_id");
        var ext = ReadString(element, "ext");
        var videoCodec = ReadString(element, "vcodec");
        var audioCodec = ReadString(element, "acodec");
        var height = ReadInt(element, "height");
        var width = ReadInt(element, "width");
        var fps = ReadDouble(element, "fps");
        var fileSize = ReadLong(element, "filesize", "filesize_approx");
        var resolution = ReadString(element, "resolution");

        if (string.IsNullOrWhiteSpace(resolution) && width is not null && height is not null)
        {
            resolution = $"{width}x{height}";
        }
        else if (string.IsNullOrWhiteSpace(resolution) && height is not null)
        {
            resolution = $"{height}p";
        }

        var isAudioOnly = string.Equals(videoCodec, "none", StringComparison.OrdinalIgnoreCase);
        if (string.IsNullOrWhiteSpace(resolution))
        {
            resolution = isAudioOnly ? "音频" : "未知";
        }

        var displayName = isAudioOnly
            ? $"音频 {formatId} ({ext})"
            : $"{resolution} {formatId} ({ext})";
        var hasVideo = !string.Equals(videoCodec, "none", StringComparison.OrdinalIgnoreCase);
        var hasAudio = !string.Equals(audioCodec, "none", StringComparison.OrdinalIgnoreCase);

        return new MediaFormat
        {
            FormatId = formatId,
            DisplayName = displayName,
            FormatSelector = formatId,
            Extension = ext,
            VideoCodec = string.IsNullOrWhiteSpace(videoCodec) ? "未知" : videoCodec,
            AudioCodec = string.IsNullOrWhiteSpace(audioCodec) ? "未知" : audioCodec,
            Resolution = resolution,
            Fps = fps,
            FileSizeBytes = fileSize,
            IsAudioOnly = isAudioOnly,
            RequiresFfmpeg = hasVideo && !hasAudio
        };
    }

    private static int ParseHeight(string resolution)
    {
        var marker = resolution.LastIndexOf('p');
        if (marker > 0 && int.TryParse(resolution[..marker], out var height))
        {
            return height;
        }

        var separator = resolution.LastIndexOf('x');
        if (separator >= 0 && int.TryParse(resolution[(separator + 1)..], out height))
        {
            return height;
        }

        return 0;
    }

    private static string CreateToolError(string prefix, string error)
    {
        if (string.IsNullOrWhiteSpace(error))
        {
            return prefix;
        }

        if (error.Contains("[BiliBili]", StringComparison.OrdinalIgnoreCase) &&
            error.Contains("HTTP Error 412", StringComparison.OrdinalIgnoreCase))
        {
            return "解析失败：B站拒绝了请求（412）。请先更新 yt-dlp；如果仍失败，在下载设置里把 cookies 来源改为 Chrome / Edge，或选择 cookies.txt 后重试。\n\n" + error.Trim();
        }

        return $"{prefix}: {error.Trim()}";
    }

    private static string ReadString(JsonElement element, params string[] names)
    {
        foreach (var name in names)
        {
            if (element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String)
            {
                return value.GetString() ?? "";
            }
        }

        return "";
    }

    private static string ReadThumbnail(JsonElement root)
    {
        var thumbnail = ReadString(root, "thumbnail");
        if (!string.IsNullOrWhiteSpace(thumbnail))
        {
            return thumbnail;
        }

        if (!root.TryGetProperty("thumbnails", out var thumbnails) || thumbnails.ValueKind != JsonValueKind.Array)
        {
            return "";
        }

        return thumbnails
            .EnumerateArray()
            .Select(item => ReadString(item, "url"))
            .Where(value => !string.IsNullOrWhiteSpace(value))
            .LastOrDefault() ?? "";
    }

    private static void AddUserNetworkArguments(
        ICollection<string> arguments,
        string cookiesSource,
        string cookiesPath,
        string proxy)
    {
        var browser = BrowserCookiesSource(cookiesSource);
        if (!string.IsNullOrWhiteSpace(browser))
        {
            arguments.Add("--cookies-from-browser");
            arguments.Add(browser);
        }
        else if (string.Equals(cookiesSource, "cookies.txt", StringComparison.OrdinalIgnoreCase) &&
                 !string.IsNullOrWhiteSpace(cookiesPath) &&
                 File.Exists(cookiesPath))
        {
            arguments.Add("--cookies");
            arguments.Add(cookiesPath);
        }

        if (!string.IsNullOrWhiteSpace(proxy))
        {
            arguments.Add("--proxy");
            arguments.Add(proxy);
        }
    }

    private static string BrowserCookiesSource(string cookiesSource)
    {
        return cookiesSource switch
        {
            var value when string.Equals(value, "Chrome", StringComparison.OrdinalIgnoreCase) => "chrome",
            var value when string.Equals(value, "Edge", StringComparison.OrdinalIgnoreCase) => "edge",
            _ => ""
        };
    }

    private static int? ReadInt(JsonElement element, string name)
    {
        return element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out var result)
            ? result
            : null;
    }

    private static long? ReadLong(JsonElement element, params string[] names)
    {
        foreach (var name in names)
        {
            if (element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt64(out var result))
            {
                return result;
            }
        }

        return null;
    }

    private static double? ReadDouble(JsonElement element, string name)
    {
        return element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetDouble(out var result)
            ? result
            : null;
    }
}

internal static class VideoInfoExtensions
{
    public static VideoInfo WithFormats(this VideoInfo videoInfo, ObservableCollection<MediaFormat> formats)
    {
        foreach (var format in formats)
        {
            videoInfo.Formats.Add(format);
        }

        return videoInfo;
    }
}
