using System.IO;
using System.Text.Json;

namespace YtDlpDownloader.Services;

public sealed class ToolPathService
{
    private readonly string _baseDirectory = AppContext.BaseDirectory;
    private readonly JsonDocument? _settings;

    public ToolPathService()
    {
        var settingsPath = Path.Combine(_baseDirectory, "appsettings.json");
        if (File.Exists(settingsPath))
        {
            _settings = JsonDocument.Parse(File.ReadAllText(settingsPath));
        }
    }

    public string ToolsDirectory => Path.Combine(_baseDirectory, "tools");
    public string BundledYtDlpPath => Path.Combine(ToolsDirectory, "yt-dlp.exe");
    public string BundledFfmpegPath => Path.Combine(ToolsDirectory, "ffmpeg.exe");
    public string BundledDenoPath => Path.Combine(ToolsDirectory, "deno.exe");

    public string YtDlpPath => ResolveToolPath("Tools", "YtDlpPath", Path.Combine("tools", "yt-dlp.exe"), "yt-dlp.exe");
    public bool HasYtDlp => File.Exists(YtDlpPath) || FindOnPath("yt-dlp.exe") is not null;

    public string? FfmpegPath
    {
        get
        {
            var configured = ResolveToolPath("Tools", "FfmpegPath", Path.Combine("tools", "ffmpeg.exe"), "");
            return string.IsNullOrWhiteSpace(configured) ? null : configured;
        }
    }
    public bool HasFfmpeg => FfmpegPath is not null && (File.Exists(FfmpegPath) || FindOnPath("ffmpeg.exe") is not null);
    public string? JsRuntimePath => FindBundledTool("deno.exe") ?? FindOnPath("deno.exe") ?? FindOnPath("node.exe");

    public IReadOnlyList<string> ExtraArguments
    {
        get
        {
            var configured = ReadStringArray("Tools", "ExtraArguments");
            if (configured.Count > 0)
            {
                return configured;
            }

            var denoPath = FindBundledTool("deno.exe") ?? FindOnPath("deno.exe");
            if (denoPath is not null)
            {
                return ["--js-runtimes", $"deno:{denoPath}"];
            }

            var nodePath = FindOnPath("node.exe");
            if (nodePath is not null)
            {
                return ["--js-runtimes", $"node:{nodePath}"];
            }

            return [];
        }
    }

    public string DefaultDownloadDirectory
    {
        get
        {
            var configured = ReadSetting("Downloads", "DefaultDirectory");
            return string.IsNullOrWhiteSpace(configured)
                ? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads")
                : ExpandPath(configured);
        }
    }

    public string GetToolStatus()
    {
        var ytDlp = File.Exists(YtDlpPath) ? YtDlpPath : HasYtDlp ? "系统 PATH: yt-dlp.exe" : "缺失";
        var ffmpeg = FfmpegPath is not null && File.Exists(FfmpegPath) ? FfmpegPath : HasFfmpeg ? "系统 PATH: ffmpeg.exe" : "缺失";
        var jsRuntime = JsRuntimePath ?? "缺失";
        return $"下载核心 yt-dlp: {ytDlp}\n视频合并 ffmpeg: {ffmpeg}\n兼容组件 Deno/Node: {jsRuntime}";
    }

    public string GetComponentSummary()
    {
        var ytDlp = HasYtDlp ? "正常" : "缺失";
        var ffmpeg = HasFfmpeg ? "正常" : "缺失";
        var jsRuntime = JsRuntimePath is null ? "建议安装" : "正常";
        return $"下载核心：{ytDlp}    视频合并：{ffmpeg}    兼容组件：{jsRuntime}\n缺失时点“修复缺失”；解析失败或站点变化时点“更新核心”。";
    }
    public void AddCommonArguments(ICollection<string> arguments)
    {
        foreach (var argument in ExtraArguments)
        {
            arguments.Add(argument);
        }
    }

    private string ResolveToolPath(string section, string name, string defaultRelativePath, string fallbackCommand)
    {
        var configured = ReadSetting(section, name);
        var relativePath = string.IsNullOrWhiteSpace(configured) ? defaultRelativePath : configured;
        var expanded = ExpandPath(relativePath);
        if (File.Exists(expanded))
        {
            return expanded;
        }

        var fromParent = FindInParentDirectories(relativePath);
        if (fromParent is not null)
        {
            return fromParent;
        }

        var fromPath = FindOnPath(Path.GetFileName(relativePath));
        return fromPath ?? fallbackCommand;
    }

    private string ExpandPath(string path)
    {
        var expanded = Environment.ExpandEnvironmentVariables(path);
        return Path.IsPathRooted(expanded) ? expanded : Path.Combine(_baseDirectory, expanded);
    }

    private string? FindInParentDirectories(string relativePath)
    {
        var directory = new DirectoryInfo(_baseDirectory);
        while (directory is not null)
        {
            var candidate = Path.Combine(directory.FullName, relativePath);
            if (File.Exists(candidate))
            {
                return candidate;
            }

            directory = directory.Parent;
        }

        return null;
    }

    private string? FindBundledTool(string executableName)
    {
        var candidate = Path.Combine(ToolsDirectory, executableName);
        return File.Exists(candidate) ? candidate : null;
    }

    private static string? FindOnPath(string executableName)
    {
        if (string.IsNullOrWhiteSpace(executableName))
        {
            return null;
        }

        var path = Environment.GetEnvironmentVariable("PATH");
        if (string.IsNullOrWhiteSpace(path))
        {
            return null;
        }

        foreach (var directory in path.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries))
        {
            var candidate = Path.Combine(directory.Trim(), executableName);
            if (File.Exists(candidate))
            {
                return candidate;
            }
        }

        return null;
    }

    private string? ReadSetting(string section, string name)
    {
        if (_settings?.RootElement.TryGetProperty(section, out var sectionElement) == true &&
            sectionElement.TryGetProperty(name, out var valueElement))
        {
            return valueElement.GetString();
        }

        return null;
    }

    private IReadOnlyList<string> ReadStringArray(string section, string name)
    {
        if (_settings?.RootElement.TryGetProperty(section, out var sectionElement) != true ||
            sectionElement.TryGetProperty(name, out var valueElement) != true ||
            valueElement.ValueKind != JsonValueKind.Array)
        {
            return [];
        }

        return valueElement
            .EnumerateArray()
            .Where(item => item.ValueKind == JsonValueKind.String)
            .Select(item => item.GetString())
            .Where(value => !string.IsNullOrWhiteSpace(value))
            .Cast<string>()
            .ToArray();
    }
}

