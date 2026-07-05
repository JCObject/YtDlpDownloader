using System.IO;
using System.IO.Compression;
using System.Net.Http;

namespace YtDlpDownloader.Services;

public sealed class ComponentRepairService
{
    private const string YtDlpUrl = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe";
    private const string DenoUrl = "https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip";
    private const string FfmpegUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip";

    private readonly ToolPathService _toolPathService;
    private readonly HttpClient _httpClient = new();

    public ComponentRepairService(ToolPathService toolPathService)
    {
        _toolPathService = toolPathService;
        _httpClient.Timeout = TimeSpan.FromMinutes(20);
    }

    public async Task RepairMissingAsync(Action<string> report, CancellationToken cancellationToken)
    {
        Directory.CreateDirectory(_toolPathService.ToolsDirectory);
        report("正在检查缺失组件...");

        var repaired = false;
        if (!_toolPathService.HasYtDlp)
        {
            await DownloadYtDlpAsync(report, cancellationToken);
            repaired = true;
        }
        else
        {
            report("下载核心已正常，跳过 yt-dlp。");
        }

        if (!_toolPathService.HasFfmpeg)
        {
            await DownloadFfmpegAsync(report, cancellationToken);
            repaired = true;
        }
        else
        {
            report("视频合并组件已正常，跳过 ffmpeg。");
        }

        if (_toolPathService.JsRuntimePath is null)
        {
            await DownloadDenoAsync(report, cancellationToken);
            repaired = true;
        }
        else
        {
            report("兼容组件已正常，跳过 Deno。");
        }

        report(repaired ? "缺失组件修复完成。" : "所有组件都已正常，无需修复。");
    }

    public async Task UpdateYtDlpAsync(Action<string> report, CancellationToken cancellationToken)
    {
        Directory.CreateDirectory(_toolPathService.ToolsDirectory);
        report("正在更新下载核心 yt-dlp...");
        await DownloadYtDlpAsync(report, cancellationToken);
        report("下载核心更新完成。");
    }

    private Task DownloadYtDlpAsync(Action<string> report, CancellationToken cancellationToken)
    {
        return DownloadFileAsync("yt-dlp", YtDlpUrl, _toolPathService.BundledYtDlpPath, report, cancellationToken);
    }

    private async Task DownloadFfmpegAsync(Action<string> report, CancellationToken cancellationToken)
    {
        var ffmpegZip = Path.Combine(_toolPathService.ToolsDirectory, "ffmpeg-release-essentials.zip");
        await DownloadFileAsync("ffmpeg", FfmpegUrl, ffmpegZip, report, cancellationToken);
        ExtractExecutable(ffmpegZip, "ffmpeg.exe", _toolPathService.BundledFfmpegPath, report);
        TryDelete(ffmpegZip);
    }

    private async Task DownloadDenoAsync(Action<string> report, CancellationToken cancellationToken)
    {
        var denoZip = Path.Combine(_toolPathService.ToolsDirectory, "deno-x86_64-pc-windows-msvc.zip");
        await DownloadFileAsync("Deno", DenoUrl, denoZip, report, cancellationToken);
        ExtractExecutable(denoZip, "deno.exe", _toolPathService.BundledDenoPath, report);
        TryDelete(denoZip);
    }

    private async Task DownloadFileAsync(
        string name,
        string url,
        string destinationPath,
        Action<string> report,
        CancellationToken cancellationToken)
    {
        report($"正在下载 {name}...");
        var tempPath = destinationPath + ".download";
        TryDelete(tempPath);

        using var response = await _httpClient.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        response.EnsureSuccessStatusCode();

        var totalBytes = response.Content.Headers.ContentLength;
        await using var source = await response.Content.ReadAsStreamAsync(cancellationToken);
        await using var destination = new FileStream(tempPath, FileMode.Create, FileAccess.Write, FileShare.None);

        var buffer = new byte[1024 * 128];
        long receivedBytes = 0;
        var lastPercent = -1;

        while (true)
        {
            var read = await source.ReadAsync(buffer, cancellationToken);
            if (read == 0)
            {
                break;
            }

            await destination.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
            receivedBytes += read;

            if (totalBytes is > 0)
            {
                var percent = (int)(receivedBytes * 100 / totalBytes.Value);
                if (percent >= lastPercent + 10 || percent == 100)
                {
                    lastPercent = percent;
                    report($"{name} 下载中：{percent}%");
                }
            }
        }

        destination.Close();
        TryDelete(destinationPath);
        File.Move(tempPath, destinationPath);
        report($"{name} 已下载。");
    }

    private static void ExtractExecutable(string archivePath, string executableName, string destinationPath, Action<string> report)
    {
        report($"正在解压 {executableName}...");
        using var archive = ZipFile.OpenRead(archivePath);
        var entry = archive.Entries.FirstOrDefault(item =>
            string.Equals(Path.GetFileName(item.FullName), executableName, StringComparison.OrdinalIgnoreCase));

        if (entry is null)
        {
            throw new InvalidOperationException($"压缩包里没有找到 {executableName}。");
        }

        TryDelete(destinationPath);
        entry.ExtractToFile(destinationPath, overwrite: true);
        report($"{executableName} 已安装。");
    }

    private static void TryDelete(string path)
    {
        try
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
        catch
        {
            // The next file operation will surface a clear error if deletion is truly blocked.
        }
    }
}
