using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Text;
using System.Windows;
using Microsoft.Win32;
using YtDlpDownloader.Infrastructure;
using YtDlpDownloader.Models;
using YtDlpDownloader.Services;

namespace YtDlpDownloader.ViewModels;

public sealed class PrimaryViewModel : ObservableObject
{
    private readonly YtDlpService _ytDlpService;
    private readonly DownloadService _downloadService;
    private readonly ToolPathService _toolPathService;
    private readonly ComponentRepairService _componentRepairService;
    private readonly UserSettingsService _userSettingsService;
    private readonly StringBuilder _logBuilder = new();
    private CancellationTokenSource? _downloadCancellation;
    private string _url = "";
    private string _saveDirectory;
    private string _outputFileName = "";
    private string _status = "输入视频链接，然后点击解析";
    private string _stage = "等待链接";
    private string _title = "尚未解析视频";
    private string _author = "";
    private string _duration = "";
    private string _thumbnailUrl = "";
    private string _sourceUrl = "";
    private string _logText = "";
    private string _componentStatus;
    private string _optionsHint = "输入视频链接后，点击解析即可看到推荐下载选项。";
    private string _primaryActionSummary = "准备好后，将在这里显示当前选择和下载状态。";
    private bool _isBusy;
    private bool _isAnalyzing;
    private bool _isDownloading;
    private bool _isRepairingComponents;
    private int _selectedTabIndex;
    private MediaFormat? _selectedSimpleFormat;
    private MediaFormat? _selectedAdvancedFormat;
    private string? _lastOutputFile;
    private string _mergeOutputFormat = "mp4";
    private string _cookiesSource = "不使用";
    private string _cookiesPath = "";
    private string _proxy = "";
    private bool _downloadSubtitles;
    private bool _downloadAutoSubtitles;
    private string _subtitleLanguages = "zh-Hans,zh-CN,en";
    private bool _downloadThumbnail;
    private FileConflictPolicyOption _selectedFileConflictPolicy = FileConflictPolicyOption.Rename;
    private string _rateLimit = "";
    private int _retryCount = 10;
    private int _concurrentFragments = 5;
    private string _extraArgumentsText = "";

    public PrimaryViewModel()
    {
        var processRunner = new ProcessRunner();
        _toolPathService = new ToolPathService();
        _userSettingsService = new UserSettingsService();
        var settingsService = new SettingsService(_toolPathService);
        var userSettings = _userSettingsService.Load();

        _ytDlpService = new YtDlpService(processRunner, _toolPathService);
        _downloadService = new DownloadService(processRunner, _toolPathService);
        _componentRepairService = new ComponentRepairService(_toolPathService);
        _saveDirectory = string.IsNullOrWhiteSpace(userSettings.SaveDirectory)
            ? settingsService.DefaultDownloadDirectory
            : userSettings.SaveDirectory;
        _mergeOutputFormat = userSettings.MergeOutputFormat;
        _cookiesSource = string.IsNullOrWhiteSpace(userSettings.CookiesSource) ? "不使用" : userSettings.CookiesSource;
        _cookiesPath = userSettings.CookiesPath;
        _proxy = userSettings.Proxy;
        _downloadSubtitles = userSettings.DownloadSubtitles;
        _downloadAutoSubtitles = userSettings.DownloadAutoSubtitles;
        _subtitleLanguages = userSettings.SubtitleLanguages;
        _downloadThumbnail = userSettings.DownloadThumbnail;
        _selectedFileConflictPolicy = FileConflictPolicyOption.FromValue(userSettings.FileConflictPolicy);
        _rateLimit = userSettings.RateLimit;
        _retryCount = userSettings.RetryCount;
        _concurrentFragments = Math.Clamp(userSettings.ConcurrentFragments, 1, 16);
        _extraArgumentsText = userSettings.ExtraArgumentsText;
        _componentStatus = _toolPathService.GetComponentSummary();

        MergeOutputFormats = ["mp4", "mkv", "auto"];
        CookieSources = ["不使用", "Chrome", "Edge", "cookies.txt"];
        FileConflictPolicies =
        [
            FileConflictPolicyOption.Rename,
            new("skip", "跳过已有文件"),
            new("overwrite", "覆盖已有文件")
        ];

        AnalyzeCommand = new AsyncRelayCommand(AnalyzeAsync, CanAnalyze);
        DownloadCommand = new AsyncRelayCommand(DownloadAsync, CanDownload);
        CancelDownloadCommand = new RelayCommand(CancelDownload, () => IsDownloading);
        BrowseDirectoryCommand = new RelayCommand(BrowseDirectory, () => CanEditInputs);
        BrowseCookiesCommand = new RelayCommand(BrowseCookies, () => CanEditInputs);
        OpenFolderCommand = new RelayCommand(OpenFolder, () => Directory.Exists(SaveDirectory));
        OpenFileCommand = new RelayCommand(OpenFile, () => !string.IsNullOrWhiteSpace(_lastOutputFile) && File.Exists(_lastOutputFile));
        CopyLogCommand = new RelayCommand(CopyLog, () => !string.IsNullOrWhiteSpace(LogText));
        ClearLogCommand = new RelayCommand(ClearLog, () => !string.IsNullOrWhiteSpace(LogText));
        RefreshComponentsCommand = new RelayCommand(RefreshComponentsWithFeedback, () => CanEditInputs);
        RepairComponentsCommand = new AsyncRelayCommand(RepairComponentsAsync, CanRepairComponents);
        UpdateCoreCommand = new AsyncRelayCommand(UpdateCoreAsync, CanRepairComponents);

        AddLog(_toolPathService.GetToolStatus());
        UpdateActionSummary();
    }

    public string Url { get => _url; set { if (SetProperty(ref _url, value)) { UpdateActionSummary(); RaiseCommandStates(); } } }
    public string SaveDirectory { get => _saveDirectory; set { if (SetProperty(ref _saveDirectory, value)) { SaveSettings(); UpdateActionSummary(); RaiseCommandStates(); } } }
    public string OutputFileName { get => _outputFileName; set { if (SetProperty(ref _outputFileName, value)) { UpdateActionSummary(); RaiseCommandStates(); } } }
    public string Status { get => _status; set => SetProperty(ref _status, value); }
    public string Stage { get => _stage; set => SetProperty(ref _stage, value); }
    public string Title { get => _title; set => SetProperty(ref _title, value); }
    public string Author { get => _author; set => SetProperty(ref _author, value); }
    public string Duration { get => _duration; set => SetProperty(ref _duration, value); }
    public string ThumbnailUrl { get => _thumbnailUrl; set => SetProperty(ref _thumbnailUrl, value); }
    public string SourceUrl { get => _sourceUrl; set => SetProperty(ref _sourceUrl, value); }
    public string ComponentStatus { get => _componentStatus; set => SetProperty(ref _componentStatus, value); }
    public string OptionsHint { get => _optionsHint; set => SetProperty(ref _optionsHint, value); }
    public string PrimaryActionSummary { get => _primaryActionSummary; set => SetProperty(ref _primaryActionSummary, value); }
    public string LogText
    {
        get => _logText;
        set
        {
            if (SetProperty(ref _logText, value))
            {
                CopyLogCommand.RaiseCanExecuteChanged();
                ClearLogCommand.RaiseCanExecuteChanged();
            }
        }
    }

    public bool IsBusy
    {
        get => _isBusy;
        set
        {
            if (SetProperty(ref _isBusy, value))
            {
                OnPropertyChanged(nameof(AnalyzeButtonText));
                OnPropertyChanged(nameof(CanEditInputs));
                RaiseCommandStates();
            }
        }
    }

    public bool IsAnalyzing
    {
        get => _isAnalyzing;
        set { if (SetProperty(ref _isAnalyzing, value)) OnPropertyChanged(nameof(AnalyzeButtonText)); }
    }

    public bool IsDownloading
    {
        get => _isDownloading;
        set { if (SetProperty(ref _isDownloading, value)) { OnPropertyChanged(nameof(CanEditInputs)); RaiseCommandStates(); } }
    }

    public bool IsRepairingComponents
    {
        get => _isRepairingComponents;
        set { if (SetProperty(ref _isRepairingComponents, value)) { OnPropertyChanged(nameof(CanEditInputs)); RaiseCommandStates(); } }
    }

    public bool CanEditInputs => !IsDownloading && !IsRepairingComponents;
    public string AnalyzeButtonText => IsAnalyzing ? "解析中..." : "解析";
    public int SelectedTabIndex { get => _selectedTabIndex; set { if (SetProperty(ref _selectedTabIndex, value)) { UpdateActionSummary(); RaiseCommandStates(); } } }
    public MediaFormat? SelectedSimpleFormat { get => _selectedSimpleFormat; set { if (SetProperty(ref _selectedSimpleFormat, value)) { UpdateActionSummary(); RaiseCommandStates(); } } }
    public MediaFormat? SelectedAdvancedFormat { get => _selectedAdvancedFormat; set { if (SetProperty(ref _selectedAdvancedFormat, value)) { UpdateActionSummary(); RaiseCommandStates(); } } }
    public string MergeOutputFormat { get => _mergeOutputFormat; set { if (SetProperty(ref _mergeOutputFormat, value)) { SaveSettings(); UpdateActionSummary(); } } }
    public string CookiesSource { get => _cookiesSource; set { if (SetProperty(ref _cookiesSource, value)) SaveSettings(); } }
    public string CookiesPath { get => _cookiesPath; set { if (SetProperty(ref _cookiesPath, value)) SaveSettings(); } }
    public string Proxy { get => _proxy; set { if (SetProperty(ref _proxy, value)) SaveSettings(); } }
    public bool DownloadSubtitles { get => _downloadSubtitles; set { if (SetProperty(ref _downloadSubtitles, value)) SaveSettings(); } }
    public bool DownloadAutoSubtitles { get => _downloadAutoSubtitles; set { if (SetProperty(ref _downloadAutoSubtitles, value)) SaveSettings(); } }
    public string SubtitleLanguages { get => _subtitleLanguages; set { if (SetProperty(ref _subtitleLanguages, value)) SaveSettings(); } }
    public bool DownloadThumbnail { get => _downloadThumbnail; set { if (SetProperty(ref _downloadThumbnail, value)) SaveSettings(); } }
    public FileConflictPolicyOption SelectedFileConflictPolicy { get => _selectedFileConflictPolicy; set { if (SetProperty(ref _selectedFileConflictPolicy, value)) SaveSettings(); } }
    public string RateLimit { get => _rateLimit; set { if (SetProperty(ref _rateLimit, value)) SaveSettings(); } }
    public int RetryCount { get => _retryCount; set { if (SetProperty(ref _retryCount, Math.Max(0, value))) SaveSettings(); } }
    public int ConcurrentFragments { get => _concurrentFragments; set { if (SetProperty(ref _concurrentFragments, Math.Clamp(value, 1, 16))) SaveSettings(); } }
    public string ExtraArgumentsText { get => _extraArgumentsText; set { if (SetProperty(ref _extraArgumentsText, value)) SaveSettings(); } }

    public ObservableCollection<MediaFormat> SimpleFormats { get; } = [];
    public ObservableCollection<MediaFormat> AdvancedFormats { get; } = [];
    public ObservableCollection<string> MergeOutputFormats { get; }
    public ObservableCollection<string> CookieSources { get; }
    public ObservableCollection<FileConflictPolicyOption> FileConflictPolicies { get; }
    public DownloadTaskViewModel CurrentTask { get; } = new();

    public AsyncRelayCommand AnalyzeCommand { get; }
    public AsyncRelayCommand DownloadCommand { get; }
    public AsyncRelayCommand RepairComponentsCommand { get; }
    public AsyncRelayCommand UpdateCoreCommand { get; }
    public RelayCommand CancelDownloadCommand { get; }
    public RelayCommand BrowseDirectoryCommand { get; }
    public RelayCommand BrowseCookiesCommand { get; }
    public RelayCommand OpenFolderCommand { get; }
    public RelayCommand OpenFileCommand { get; }
    public RelayCommand CopyLogCommand { get; }
    public RelayCommand ClearLogCommand { get; }
    public RelayCommand RefreshComponentsCommand { get; }

    private MediaFormat? SelectedFormat => SelectedTabIndex == 1 ? SelectedAdvancedFormat : SelectedSimpleFormat;

    private async Task AnalyzeAsync(CancellationToken cancellationToken)
    {
        if (!TryValidateUrl(Url, out var normalizedUrl, out var validationMessage))
        {
            ClearParsedVideo();
            Stage = "链接有误";
            Status = validationMessage;
            OptionsHint = "请粘贴完整的视频网址，然后再点击解析。";
            AddLog(validationMessage);
            return;
        }

        try
        {
            IsBusy = true;
            IsAnalyzing = true;
            Stage = "解析中";
            Status = "正在获取视频信息，请稍候...";
            OptionsHint = "正在读取标题、封面和可下载格式...";
            ClearLog();
            RefreshComponents();
            AddLog(_toolPathService.GetToolStatus());

            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            timeout.CancelAfter(TimeSpan.FromSeconds(90));
            var videoInfo = await _ytDlpService.GetVideoInfoAsync(
                normalizedUrl,
                CookiesSource,
                CookiesPath,
                Proxy,
                AddLog,
                timeout.Token);
            Title = videoInfo.Title;
            Author = videoInfo.Author;
            Duration = videoInfo.Duration is null ? "未知时长" : videoInfo.Duration.Value.ToString(@"hh\:mm\:ss");
            ThumbnailUrl = videoInfo.ThumbnailUrl;
            SourceUrl = videoInfo.SourceUrl;
            OutputFileName = SanitizeFileName(videoInfo.Title);

            SimpleFormats.Clear();
            AdvancedFormats.Clear();
            foreach (var format in videoInfo.Formats)
            {
                if (format.IsSimpleOption) SimpleFormats.Add(format);
                else AdvancedFormats.Add(format);
            }

            SelectedSimpleFormat = SimpleFormats.FirstOrDefault(format => format.FormatId == "recommended-best") ?? SimpleFormats.FirstOrDefault();
            SelectedAdvancedFormat = AdvancedFormats.FirstOrDefault();
            Stage = "已解析";
            Status = "请选择清晰度，然后点击开始下载";
            OptionsHint = "高级格式适合了解 format_id 的用户；普通下载建议使用简单下载。需合并表示该格式只有视频轨，会自动和音频合并。";
            UpdateActionSummary();
        }
        catch (Exception ex)
        {
            ClearParsedVideo();
            Stage = "解析失败";
            Status = ToUserFacingParseStatus(ex);
            OptionsHint = "没有获取到视频信息。可以换一个链接，或稍后重试。";
            AddLog(ToFriendlyError(ex));
        }
        finally
        {
            IsAnalyzing = false;
            IsBusy = false;
        }
    }

    private async Task DownloadAsync(CancellationToken cancellationToken)
    {
        var selectedFormat = SelectedFormat;
        if (selectedFormat is null)
        {
            Status = "请先选择下载选项";
            return;
        }

        if (!_toolPathService.HasFfmpeg)
        {
            Stage = "缺少组件";
            Status = "缺少 ffmpeg，无法完成视频合并";
            AddLog("ffmpeg 是必备组件。请把 ffmpeg.exe 放到 tools 目录后重试。");
            return;
        }

        try
        {
            IsBusy = true;
            IsDownloading = true;
            _downloadCancellation = new CancellationTokenSource();
            Directory.CreateDirectory(SaveDirectory);
            CurrentTask.Progress = 0;
            CurrentTask.Stage = "准备下载";
            Stage = "下载中";
            Status = "正在下载，请保持窗口打开";
            SaveSettings();

            var safeName = SanitizeFileName(OutputFileName);
            if (SelectedFileConflictPolicy.Value == "rename")
            {
                safeName = MakeUniqueBaseName(SaveDirectory, safeName);
            }

            var outputTemplate = Path.Combine(SaveDirectory, $"{safeName}.%(ext)s");
            _lastOutputFile = null;
            var startedAt = DateTime.Now.AddSeconds(-2);

            var task = new DownloadTask
            {
                Url = Url.Trim(),
                OutputTemplate = outputTemplate,
                Format = selectedFormat,
                FfmpegPath = _toolPathService.FfmpegPath,
                Options = BuildOptions()
            };

            await _downloadService.DownloadAsync(task, ApplyProgress, _downloadCancellation.Token);
            _lastOutputFile = FindLatestOutputFile(SaveDirectory, safeName, startedAt);
            CurrentTask.Progress = 100;
            CurrentTask.Stage = "完成";
            Stage = "下载完成";
            Status = "下载完成，可以打开文件或所在目录";
            AddLog(_lastOutputFile is null ? "下载完成，但未能自动定位最终文件。" : $"已保存: {_lastOutputFile}");
        }
        catch (OperationCanceledException)
        {
            Stage = "已取消";
            Status = "下载已取消";
            AddLog("下载已取消。");
        }
        catch (Exception ex)
        {
            Stage = "下载失败";
            Status = "下载失败，详情见日志";
            AddLog(ToFriendlyError(ex));
        }
        finally
        {
            _downloadCancellation?.Dispose();
            _downloadCancellation = null;
            IsDownloading = false;
            IsBusy = false;
            UpdateActionSummary();
            RaiseCommandStates();
        }
    }

    private void CancelDownload()
    {
        _downloadCancellation?.Cancel();
        Status = "正在取消下载...";
    }

    private DownloadOptions BuildOptions()
    {
        return new DownloadOptions
        {
            MergeOutputFormat = MergeOutputFormat,
            CookiesSource = CookiesSource,
            CookiesPath = string.IsNullOrWhiteSpace(CookiesPath) ? null : CookiesPath,
            Proxy = string.IsNullOrWhiteSpace(Proxy) ? null : Proxy,
            DownloadSubtitles = DownloadSubtitles,
            DownloadAutoSubtitles = DownloadAutoSubtitles,
            SubtitleLanguages = SubtitleLanguages,
            DownloadThumbnail = DownloadThumbnail,
            FileConflictPolicy = SelectedFileConflictPolicy.Value,
            RateLimit = string.IsNullOrWhiteSpace(RateLimit) ? null : RateLimit,
            RetryCount = RetryCount,
            ConcurrentFragments = ConcurrentFragments,
            ExtraArgumentsText = string.IsNullOrWhiteSpace(ExtraArgumentsText) ? null : ExtraArgumentsText
        };
    }

    private void SaveSettings()
    {
        _userSettingsService.Save(new UserDownloadSettings
        {
            SaveDirectory = SaveDirectory,
            MergeOutputFormat = MergeOutputFormat,
            CookiesSource = CookiesSource,
            CookiesPath = CookiesPath,
            Proxy = Proxy,
            DownloadSubtitles = DownloadSubtitles,
            DownloadAutoSubtitles = DownloadAutoSubtitles,
            SubtitleLanguages = SubtitleLanguages,
            DownloadThumbnail = DownloadThumbnail,
            FileConflictPolicy = SelectedFileConflictPolicy.Value,
            RateLimit = RateLimit,
            RetryCount = RetryCount,
            ConcurrentFragments = ConcurrentFragments,
            ExtraArgumentsText = ExtraArgumentsText
        });
    }

    private void UpdateActionSummary()
    {
        var selected = SelectedFormat;
        if (selected is null)
        {
            PrimaryActionSummary = string.IsNullOrWhiteSpace(Url)
                ? "第 1 步：粘贴视频链接并点击解析。"
                : "第 2 步：解析后选择一个下载选项。";
            return;
        }

        var merge = selected.RequiresFfmpeg ? $"，合并为 {MergeOutputFormat}" : "";
        PrimaryActionSummary = $"将下载：{selected.DisplayName}{merge}，保存到 {SaveDirectory}";
    }

    private void BrowseDirectory()
    {
        var dialog = new OpenFolderDialog
        {
            Title = "选择保存目录",
            InitialDirectory = Directory.Exists(SaveDirectory) ? SaveDirectory : Environment.GetFolderPath(Environment.SpecialFolder.UserProfile)
        };

        if (dialog.ShowDialog() == true) SaveDirectory = dialog.FolderName;
    }

    private void BrowseCookies()
    {
        var dialog = new OpenFileDialog
        {
            Title = "选择 cookies.txt",
            Filter = "Cookies 文件 (*.txt)|*.txt|所有文件 (*.*)|*.*"
        };

        if (dialog.ShowDialog() == true)
        {
            CookiesPath = dialog.FileName;
            CookiesSource = "cookies.txt";
        }
    }

    private void OpenFolder()
    {
        if (Directory.Exists(SaveDirectory)) StartShell("explorer.exe", SaveDirectory);
    }

    private void OpenFile()
    {
        if (!string.IsNullOrWhiteSpace(_lastOutputFile) && File.Exists(_lastOutputFile)) StartShell(_lastOutputFile, "");
    }

    private void CopyLog()
    {
        if (!string.IsNullOrWhiteSpace(LogText)) Clipboard.SetText(LogText);
    }

    private void ClearLog()
    {
        _logBuilder.Clear();
        LogText = "";
    }

    private void ClearParsedVideo()
    {
        Title = "尚未解析视频";
        Author = "";
        Duration = "";
        ThumbnailUrl = "";
        SourceUrl = "";
        OutputFileName = "";
        SimpleFormats.Clear();
        AdvancedFormats.Clear();
        SelectedSimpleFormat = null;
        SelectedAdvancedFormat = null;
        CurrentTask.Progress = 0;
        CurrentTask.Stage = "";
        UpdateActionSummary();
        RaiseCommandStates();
    }

    private void RefreshComponents() => ComponentStatus = _toolPathService.GetComponentSummary();

    private void RefreshComponentsWithFeedback()
    {
        RefreshComponents();
        Stage = "组件检查";
        Status = "已重新检查组件状态";
        AddLog("已重新检查组件状态。");
        AddLog(_toolPathService.GetToolStatus());
    }

    private async Task RepairComponentsAsync(CancellationToken cancellationToken)
    {
        try
        {
            IsBusy = true;
            IsRepairingComponents = true;
            Stage = "修复组件";
            Status = "正在检查并修复缺失组件，请稍候...";
            ClearLog();
            AddLog("组件将安装到程序目录下的 tools 文件夹，不会修改系统 PATH。");

            await _componentRepairService.RepairMissingAsync(AddLog, cancellationToken);
            RefreshComponents();
            AddLog(_toolPathService.GetToolStatus());
            Stage = "组件正常";
            Status = "组件检查完成，可以开始解析视频";
        }
        catch (Exception ex)
        {
            Stage = "修复失败";
            Status = "组件修复失败，详情见日志";
            AddLog(ToFriendlyRepairError(ex));
        }
        finally
        {
            IsRepairingComponents = false;
            IsBusy = false;
            RefreshComponents();
            RaiseCommandStates();
        }
    }

    private async Task UpdateCoreAsync(CancellationToken cancellationToken)
    {
        try
        {
            IsBusy = true;
            IsRepairingComponents = true;
            Stage = "更新核心";
            Status = "正在更新 yt-dlp，请稍候...";
            ClearLog();
            AddLog("下载核心 yt-dlp 更新后，通常可以修复站点规则变化导致的解析失败。");

            await _componentRepairService.UpdateYtDlpAsync(AddLog, cancellationToken);
            RefreshComponents();
            AddLog(_toolPathService.GetToolStatus());
            Stage = "更新完成";
            Status = "下载核心已更新，可以重新解析视频";
        }
        catch (Exception ex)
        {
            Stage = "更新失败";
            Status = "下载核心更新失败，详情见日志";
            AddLog(ToFriendlyRepairError(ex));
        }
        finally
        {
            IsRepairingComponents = false;
            IsBusy = false;
            RefreshComponents();
            RaiseCommandStates();
        }
    }
    private void ApplyProgress(DownloadProgress progress)
    {
        Application.Current.Dispatcher.Invoke(() =>
        {
            CurrentTask.Apply(progress);
            Stage = progress.Stage;
            if (progress.ShowInLog && !string.IsNullOrWhiteSpace(progress.Message)) AddLog(progress.Message);
        });
    }

    private void AddLog(string line)
    {
        void Append()
        {
            _logBuilder.AppendLine(line);
            LogText = _logBuilder.ToString();
        }

        if (Application.Current?.Dispatcher.CheckAccess() == true) Append();
        else Application.Current?.Dispatcher.Invoke(Append);
    }

    private bool CanAnalyze() => !IsBusy && !string.IsNullOrWhiteSpace(Url);

    private bool CanRepairComponents() => !IsBusy && !IsRepairingComponents;

    private bool CanDownload()
    {
        return !IsBusy &&
               !string.IsNullOrWhiteSpace(Url) &&
               SelectedFormat is not null &&
               !string.IsNullOrWhiteSpace(SaveDirectory) &&
               !string.IsNullOrWhiteSpace(OutputFileName);
    }

    private void RaiseCommandStates()
    {
        AnalyzeCommand.RaiseCanExecuteChanged();
        DownloadCommand.RaiseCanExecuteChanged();
        RepairComponentsCommand.RaiseCanExecuteChanged();
        UpdateCoreCommand.RaiseCanExecuteChanged();
        CancelDownloadCommand.RaiseCanExecuteChanged();
        BrowseDirectoryCommand.RaiseCanExecuteChanged();
        BrowseCookiesCommand.RaiseCanExecuteChanged();
        OpenFolderCommand.RaiseCanExecuteChanged();
        OpenFileCommand.RaiseCanExecuteChanged();
        CopyLogCommand.RaiseCanExecuteChanged();
        ClearLogCommand.RaiseCanExecuteChanged();
        RefreshComponentsCommand.RaiseCanExecuteChanged();
    }

    private static string SanitizeFileName(string fileName)
    {
        var sanitized = string.Join("_", fileName.Split(Path.GetInvalidFileNameChars(), StringSplitOptions.RemoveEmptyEntries)).Trim();
        return string.IsNullOrWhiteSpace(sanitized) ? "download" : sanitized;
    }

    private static string MakeUniqueBaseName(string directory, string baseName)
    {
        if (!Directory.Exists(directory) || !Directory.EnumerateFiles(directory, $"{baseName}.*").Any()) return baseName;
        return $"{baseName}_{DateTime.Now:yyyyMMdd_HHmmss}";
    }

    private static string? FindLatestOutputFile(string directory, string fileNameWithoutExtension, DateTime startedAt)
    {
        if (!Directory.Exists(directory)) return null;

        return Directory
            .EnumerateFiles(directory, $"{fileNameWithoutExtension}.*")
            .Where(path => !path.EndsWith(".part", StringComparison.OrdinalIgnoreCase) && !path.EndsWith(".ytdl", StringComparison.OrdinalIgnoreCase))
            .Select(path => new FileInfo(path))
            .Where(file => file.LastWriteTime >= startedAt)
            .OrderByDescending(file => file.LastWriteTime)
            .FirstOrDefault()
            ?.FullName;
    }

    private static string ToFriendlyError(Exception exception)
    {
        return exception switch
        {
            OperationCanceledException => "解析超时或已取消，请检查链接和网络后重试。",
            System.ComponentModel.Win32Exception => "未能启动 yt-dlp。请把 yt-dlp.exe 放到 tools 目录，或确保 yt-dlp 已加入 PATH。",
            _ => exception.Message
        };
    }

    private static string ToFriendlyRepairError(Exception exception)
    {
        return exception switch
        {
            OperationCanceledException => "组件修复已取消。",
            HttpRequestException => "组件下载失败，请检查网络或稍后重试。\n" + exception.Message,
            UnauthorizedAccessException => "没有权限写入 tools 目录。请关闭正在使用的组件文件，或把程序放到当前用户可写的目录后重试。",
            IOException => "写入组件文件失败。请关闭正在运行的下载进程或播放器后重试。\n" + exception.Message,
            _ => exception.Message
        };
    }

    private static bool TryValidateUrl(string value, out string normalizedUrl, out string message)
    {
        normalizedUrl = value.Trim();
        if (string.IsNullOrWhiteSpace(normalizedUrl))
        {
            message = "请先输入视频链接。";
            return false;
        }

        if (!Uri.TryCreate(normalizedUrl, UriKind.Absolute, out var uri))
        {
            message = "链接格式不正确，请粘贴完整的视频网址，例如 https://www.youtube.com/watch?v=...";
            return false;
        }

        if (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps)
        {
            message = "仅支持 http 或 https 开头的视频链接。";
            return false;
        }

        message = "";
        normalizedUrl = uri.ToString();
        return true;
    }

    private static string ToUserFacingParseStatus(Exception exception)
    {
        var message = exception.Message;
        if (exception is OperationCanceledException)
        {
            return "解析超时，请检查网络后重试";
        }

        if (message.Contains("不是可下载的视频页面", StringComparison.OrdinalIgnoreCase) ||
            message.Contains("完整的视频网址", StringComparison.OrdinalIgnoreCase))
        {
            return "解析失败：这不是有效的视频页面";
        }

        if (message.Contains("Unsupported URL", StringComparison.OrdinalIgnoreCase) ||
            message.Contains("not a valid URL", StringComparison.OrdinalIgnoreCase))
        {
            return "解析失败：这个链接不是支持的视频网址";
        }

        if (message.Contains("Video unavailable", StringComparison.OrdinalIgnoreCase) ||
            message.Contains("This video is unavailable", StringComparison.OrdinalIgnoreCase) ||
            message.Contains("Private video", StringComparison.OrdinalIgnoreCase))
        {
            return "解析失败：视频可能不存在、私密或无法访问";
        }

        if (message.Contains("[BiliBili]", StringComparison.OrdinalIgnoreCase) &&
            message.Contains("HTTP Error 412", StringComparison.OrdinalIgnoreCase))
        {
            return "解析失败：该视频可能需要登录、cookies 或稍后重试";
        }

        if (message.Contains("HTTP Error 403", StringComparison.OrdinalIgnoreCase) ||
            message.Contains("Sign in", StringComparison.OrdinalIgnoreCase) ||
            message.Contains("cookies", StringComparison.OrdinalIgnoreCase))
        {
            return "解析失败：该视频可能需要登录、cookies 或稍后重试";
        }

        if (message.Contains("Unable to download webpage", StringComparison.OrdinalIgnoreCase) ||
            message.Contains("timed out", StringComparison.OrdinalIgnoreCase) ||
            message.Contains("Network", StringComparison.OrdinalIgnoreCase))
        {
            return "解析失败：网络连接异常，请稍后重试";
        }

        return "解析失败：无法获取视频信息";
    }

    private static void StartShell(string fileName, string arguments)
    {
        Process.Start(new ProcessStartInfo { FileName = fileName, Arguments = arguments, UseShellExecute = true });
    }
}

public sealed record FileConflictPolicyOption(string Value, string Label)
{
    public static FileConflictPolicyOption Rename { get; } = new("rename", "自动改名（推荐）");
    public override string ToString() => Label;

    public static FileConflictPolicyOption FromValue(string value)
    {
        return value switch
        {
            "skip" => new FileConflictPolicyOption("skip", "跳过已有文件"),
            "overwrite" => new FileConflictPolicyOption("overwrite", "覆盖已有文件"),
            _ => Rename
        };
    }
}


