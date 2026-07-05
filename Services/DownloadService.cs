using System.Text.RegularExpressions;
using System.IO;
using YtDlpDownloader.Infrastructure;
using YtDlpDownloader.Models;

namespace YtDlpDownloader.Services;

public sealed partial class DownloadService
{
    private readonly ProcessRunner _processRunner;
    private readonly ToolPathService _toolPathService;

    public DownloadService(ProcessRunner processRunner, ToolPathService toolPathService)
    {
        _processRunner = processRunner;
        _toolPathService = toolPathService;
    }

    public async Task DownloadAsync(
        DownloadTask task,
        Action<DownloadProgress> onProgress,
        CancellationToken cancellationToken)
    {
        if (task.Format.RequiresFfmpeg && (string.IsNullOrWhiteSpace(task.FfmpegPath) || !File.Exists(task.FfmpegPath)))
        {
            throw new InvalidOperationException("当前选项需要 ffmpeg 合并音视频。请把 ffmpeg.exe 放到 tools 目录，或选择“单文件 MP4 / 仅音频”。");
        }

        var sourceUrl = YtDlpUrlHelper.Normalize(task.Url);
        var arguments = new List<string>
        {
            "--newline",
            "--no-playlist",
            "--windows-filenames",
            "--concurrent-fragments",
            Math.Clamp(task.Options.ConcurrentFragments, 1, 16).ToString(),
            "--retries",
            Math.Max(0, task.Options.RetryCount).ToString(),
            "-f",
            task.Format.FormatSelector,
            "-o",
            task.OutputTemplate
        };
        _toolPathService.AddCommonArguments(arguments);
        YtDlpUrlHelper.AddSiteArguments(arguments, sourceUrl);

        AddDownloadOptions(arguments, task.Options);

        if (!string.IsNullOrWhiteSpace(task.FfmpegPath) && File.Exists(task.FfmpegPath))
        {
            arguments.Add("--ffmpeg-location");
            arguments.Add(Path.GetDirectoryName(task.FfmpegPath)!);
        }

        arguments.Add(sourceUrl);

        var result = await _processRunner.RunAsync(
            _toolPathService.YtDlpPath,
            arguments,
            line => onProgress(ParseProgressLine(line)),
            cancellationToken);

        if (result.ExitCode != 0)
        {
            throw new InvalidOperationException(ToFriendlyYtDlpError(result.Error));
        }
    }

    private static void AddDownloadOptions(ICollection<string> arguments, DownloadOptions options)
    {
        if (!string.Equals(options.MergeOutputFormat, "auto", StringComparison.OrdinalIgnoreCase))
        {
            arguments.Add("--merge-output-format");
            arguments.Add(options.MergeOutputFormat);
        }

        if (!string.IsNullOrWhiteSpace(options.CookiesPath) && File.Exists(options.CookiesPath))
        {
            arguments.Add("--cookies");
            arguments.Add(options.CookiesPath);
        }

        if (!string.IsNullOrWhiteSpace(options.Proxy))
        {
            arguments.Add("--proxy");
            arguments.Add(options.Proxy);
        }

        if (options.DownloadSubtitles)
        {
            arguments.Add("--write-subs");
        }

        if (options.DownloadAutoSubtitles)
        {
            arguments.Add("--write-auto-subs");
        }

        if (options.DownloadSubtitles || options.DownloadAutoSubtitles)
        {
            arguments.Add("--sub-langs");
            arguments.Add(string.IsNullOrWhiteSpace(options.SubtitleLanguages) ? "all" : options.SubtitleLanguages);
        }

        if (options.DownloadThumbnail)
        {
            arguments.Add("--write-thumbnail");
        }

        if (string.Equals(options.FileConflictPolicy, "overwrite", StringComparison.OrdinalIgnoreCase))
        {
            arguments.Add("--force-overwrites");
        }
        else if (string.Equals(options.FileConflictPolicy, "skip", StringComparison.OrdinalIgnoreCase))
        {
            arguments.Add("--no-overwrites");
        }

        if (!string.IsNullOrWhiteSpace(options.RateLimit))
        {
            arguments.Add("--limit-rate");
            arguments.Add(options.RateLimit);
        }

        foreach (var argument in SplitExtraArguments(options.ExtraArgumentsText))
        {
            arguments.Add(argument);
        }
    }

    private static IEnumerable<string> SplitExtraArguments(string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            yield break;
        }

        foreach (Match match in ExtraArgumentRegex().Matches(text))
        {
            yield return match.Groups["quoted"].Success
                ? match.Groups["quoted"].Value
                : match.Groups["plain"].Value;
        }
    }

    private static string ToFriendlyYtDlpError(string error)
    {
        if (string.IsNullOrWhiteSpace(error))
        {
            return "下载失败。";
        }

        if (error.Contains("HTTP Error 403", StringComparison.OrdinalIgnoreCase) &&
            error.Contains("JavaScript runtime", StringComparison.OrdinalIgnoreCase))
        {
            return "下载失败：YouTube 返回 403，并且 yt-dlp 没有可用的 JavaScript runtime。请安装 Deno，或确保 Node.js 在 PATH 中，然后重启应用；也可以在 appsettings.json 的 Tools.ExtraArguments 中配置 --js-runtimes。";
        }

        if (error.Contains("[BiliBili]", StringComparison.OrdinalIgnoreCase) &&
            error.Contains("HTTP Error 412", StringComparison.OrdinalIgnoreCase))
        {
            return "下载失败：B站拒绝了请求（412）。请更新 yt-dlp，或在下载设置里选择 cookies.txt 后重试。\n\n" + error.Trim();
        }

        if (error.Contains("HTTP Error 403", StringComparison.OrdinalIgnoreCase))
        {
            return "下载失败：YouTube 返回 403。通常需要更新 yt-dlp，或配置 cookies / JavaScript runtime 后重试。\n\n" + error.Trim();
        }

        return error.Trim();
    }

    private static DownloadProgress ParseProgressLine(string line)
    {
        var stage = line switch
        {
            var text when text.Contains("[download]", StringComparison.OrdinalIgnoreCase) => "下载中",
            var text when text.Contains("[Merger]", StringComparison.OrdinalIgnoreCase) => "合并音视频",
            var text when text.Contains("[ExtractAudio]", StringComparison.OrdinalIgnoreCase) => "提取音频",
            var text when text.Contains("[ffmpeg]", StringComparison.OrdinalIgnoreCase) => "后处理",
            var text when text.Contains("[info]", StringComparison.OrdinalIgnoreCase) => "准备中",
            _ => "运行中"
        };
        var showInLog = ShouldShowInUserLog(line);

        var match = DownloadProgressRegex().Match(line);
        if (!match.Success)
        {
            return new DownloadProgress { Stage = stage, Message = NormalizeLogMessage(line), ShowInLog = showInLog };
        }

        return new DownloadProgress
        {
            Percentage = double.TryParse(match.Groups["percent"].Value, out var percent) ? percent : null,
            Downloaded = match.Groups["size"].Value,
            Speed = match.Groups["speed"].Value,
            Eta = match.Groups["eta"].Value,
            Stage = stage,
            Message = NormalizeLogMessage(line),
            ShowInLog = showInLog
        };
    }

    private static bool ShouldShowInUserLog(string line)
    {
        if (line.Contains("[Merger]", StringComparison.OrdinalIgnoreCase) ||
            line.Contains("Deleting original file", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        return true;
    }

    private static string NormalizeLogMessage(string line)
    {
        if (line.Contains("[Merger]", StringComparison.OrdinalIgnoreCase))
        {
            return "正在合并音视频...";
        }

        if (line.Contains("Deleting original file", StringComparison.OrdinalIgnoreCase))
        {
            return "正在清理临时文件...";
        }

        return line;
    }

    [GeneratedRegex(@"(?<percent>\d+(?:\.\d+)?)%\s+of\s+(?<size>\S+).*?at\s+(?<speed>\S+).*?ETA\s+(?<eta>\S+)", RegexOptions.IgnoreCase)]
    private static partial Regex DownloadProgressRegex();

    [GeneratedRegex("""(?:"(?<quoted>[^"]*)"|(?<plain>\S+))""")]
    private static partial Regex ExtraArgumentRegex();
}
