using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
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
    private FileConflictPolicyOption _selectedFileConflictPolicy = new("rename", "自动改名（推荐）");
    private string _rateLimit = "";
    private int _retryCount = 10;
    private int _concurrentFragments = 5;
    private string _extraArgumentsText = "";
    private LanguageOption _selectedLanguageOption = LanguageOption.English;

    public PrimaryViewModel()
    {
        var processRunner = new ProcessRunner();
        _toolPathService = new ToolPathService();
        _userSettingsService = new UserSettingsService();
        var settingsService = new SettingsService(_toolPathService);
        var userSettings = _userSettingsService.Load();
        LanguageOptions =
        [
            LanguageOption.Chinese,
            LanguageOption.English
        ];
        _selectedLanguageOption = LanguageOption.FromValue(userSettings.Language);
        Text = new LocalizationService(_selectedLanguageOption.Value);
        _status = Text["StatusEnterUrl"];
        _stage = Text["StageWaitingLink"];
        _title = Text["TitleNotParsed"];
        _optionsHint = Text["OptionsHintInitial"];
        _primaryActionSummary = Text["ActionInitial"];

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
        _selectedFileConflictPolicy = FileConflictPolicyOption.FromValue(userSettings.FileConflictPolicy, Text);
        _rateLimit = userSettings.RateLimit;
        _retryCount = userSettings.RetryCount;
        _concurrentFragments = Math.Clamp(userSettings.ConcurrentFragments, 1, 16);
        _extraArgumentsText = userSettings.ExtraArgumentsText;
        _componentStatus = GetLocalizedComponentSummary();

        MergeOutputFormats = ["mp4", "mkv", "auto"];
        CookieSources = ["不使用", "Chrome", "Edge", "cookies.txt"];
        FileConflictPolicies =
        [
            FileConflictPolicyOption.Rename(Text),
            new("skip", Text["FileConflictSkip"]),
            new("overwrite", Text["FileConflictOverwrite"])
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

        AddLog(GetLocalizedToolStatus());
        UpdateActionSummary();
    }

    public LocalizationService Text { get; }
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
    public string AnalyzeButtonText => IsAnalyzing ? Text["ButtonAnalyzing"] : Text["ButtonAnalyze"];
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
    public LanguageOption SelectedLanguageOption
    {
        get => _selectedLanguageOption;
        set
        {
            var previous = _selectedLanguageOption;
            if (value == previous)
            {
                return;
            }

            if (!ConfirmRestartForLanguageChange())
            {
                SetProperty(ref _selectedLanguageOption, value);
                Application.Current.Dispatcher.BeginInvoke(
                    () => SetProperty(ref _selectedLanguageOption, previous),
                    DispatcherPriority.ApplicationIdle);
                return;
            }

            if (SetProperty(ref _selectedLanguageOption, value))
            {
                SaveSettings();
                RestartApplication();
            }
        }
    }

    public ObservableCollection<MediaFormat> SimpleFormats { get; } = [];
    public ObservableCollection<MediaFormat> AdvancedFormats { get; } = [];
    public ObservableCollection<string> MergeOutputFormats { get; }
    public ObservableCollection<string> CookieSources { get; }
    public ObservableCollection<FileConflictPolicyOption> FileConflictPolicies { get; }
    public ObservableCollection<LanguageOption> LanguageOptions { get; }
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
            Stage = Text["StageInvalidLink"];
            Status = validationMessage;
            OptionsHint = Text["OptionsHintInvalidLink"];
            AddLog(validationMessage);
            return;
        }

        try
        {
            IsBusy = true;
            IsAnalyzing = true;
            Stage = Text["StageAnalyzing"];
            Status = Text["StatusAnalyzing"];
            OptionsHint = Text["OptionsHintAnalyzing"];
            ClearLog();
            RefreshComponents();
            AddLog(GetLocalizedToolStatus());

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
            Duration = videoInfo.Duration is null ? Text["DurationUnknown"] : videoInfo.Duration.Value.ToString(@"hh\:mm\:ss");
            ThumbnailUrl = videoInfo.ThumbnailUrl;
            SourceUrl = videoInfo.SourceUrl;
            OutputFileName = SanitizeFileName(videoInfo.Title);

            SimpleFormats.Clear();
            AdvancedFormats.Clear();
            foreach (var format in videoInfo.Formats)
            {
                var localizedFormat = LocalizeFormat(format);
                if (localizedFormat.IsSimpleOption) SimpleFormats.Add(localizedFormat);
                else AdvancedFormats.Add(localizedFormat);
            }

            SelectedSimpleFormat = SimpleFormats.FirstOrDefault(format => format.FormatId == "recommended-best") ?? SimpleFormats.FirstOrDefault();
            SelectedAdvancedFormat = AdvancedFormats.FirstOrDefault();
            Stage = Text["StageAnalyzed"];
            Status = Text["StatusChooseQuality"];
            OptionsHint = Text["OptionsHintAdvanced"];
            UpdateActionSummary();
        }
        catch (Exception ex)
        {
            ClearParsedVideo();
            Stage = Text["StageParseFailed"];
            Status = ToUserFacingParseStatus(ex);
            OptionsHint = Text["OptionsHintParseFailed"];
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
            Status = Text["StatusSelectDownloadOption"];
            return;
        }

        if (!_toolPathService.HasFfmpeg)
        {
            Stage = Text["StageMissingComponent"];
            Status = Text["StatusMissingFfmpeg"];
            AddLog(Text["LogMissingFfmpeg"]);
            return;
        }

        try
        {
            IsBusy = true;
            IsDownloading = true;
            _downloadCancellation = new CancellationTokenSource();
            Directory.CreateDirectory(SaveDirectory);
            CurrentTask.Progress = 0;
            CurrentTask.Stage = Text["TaskPreparing"];
            Stage = Text["StageDownloading"];
            Status = Text["StatusDownloading"];
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
            CurrentTask.Stage = Text["TaskComplete"];
            Stage = Text["StageDownloadComplete"];
            Status = Text["StatusDownloadComplete"];
            AddLog(_lastOutputFile is null ? Text["LogCompleteNoFile"] : string.Format(Text["LogSaved"], _lastOutputFile));
        }
        catch (OperationCanceledException)
        {
            Stage = Text["StageCanceled"];
            Status = Text["StatusCanceled"];
            AddLog(Text["LogCanceled"]);
        }
        catch (Exception ex)
        {
            Stage = Text["StageDownloadFailed"];
            Status = Text["StatusDownloadFailed"];
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
        Status = Text["StatusCanceling"];
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
            Language = SelectedLanguageOption.Value,
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
                ? Text["ActionStepPaste"]
                : Text["ActionStepChoose"];
            return;
        }

        var merge = selected.RequiresFfmpeg ? string.Format(Text["ActionMergeAs"], MergeOutputFormat) : "";
        PrimaryActionSummary = string.Format(Text["ActionWillDownload"], selected.DisplayName, merge, SaveDirectory);
    }

    private MediaFormat LocalizeFormat(MediaFormat format)
    {
        var extension = LocalizeFormatToken(format.Extension);
        var videoCodec = LocalizeFormatToken(format.VideoCodec);
        var audioCodec = LocalizeFormatToken(format.AudioCodec);
        var resolution = LocalizeResolution(format.Resolution);
        var displayName = LocalizeDisplayName(format, extension, resolution);

        return new MediaFormat
        {
            FormatId = format.FormatId,
            DisplayName = displayName,
            FormatSelector = format.FormatSelector,
            Extension = extension,
            VideoCodec = videoCodec,
            AudioCodec = audioCodec,
            Resolution = resolution,
            Fps = format.Fps,
            FileSizeBytes = format.FileSizeBytes,
            IsRecommended = format.IsRecommended,
            IsAudioOnly = format.IsAudioOnly,
            RequiresFfmpeg = format.RequiresFfmpeg,
            IsSimpleOption = format.IsSimpleOption,
            KindLabel = format.IsAudioOnly ? Text["FormatAudio"] : format.RequiresFfmpeg ? Text["FormatNeedsMerge"] : Text["FormatSingleFile"],
            UnknownText = Text["FormatUnknown"]
        };
    }

    private string LocalizeDisplayName(MediaFormat format, string extension, string resolution)
    {
        return format.FormatId switch
        {
            "recommended-best" => Text["FormatBest"],
            "recommended-single-mp4" => Text["FormatSingleMp4"],
            "recommended-audio" => Text["FormatAudioOnly"],
            "recommended-1080p" => "1080p",
            "recommended-720p" => "720p",
            _ when format.IsAudioOnly => $"{Text["FormatAudio"]} {format.FormatId} ({extension})",
            _ => $"{resolution} {format.FormatId} ({extension})"
        };
    }

    private string LocalizeResolution(string value)
    {
        var normalized = NormalizeChineseToken(value);
        return normalized switch
        {
            "auto" => Text["FormatAuto"],
            "unknown" => Text["FormatUnknown"],
            "audio" => Text["FormatAudio"],
            "best" => Text["FormatBestAvailable"],
            "1080p-or-lower" => string.Format(Text["FormatOrLower"], "1080p"),
            "720p-or-lower" => string.Format(Text["FormatOrLower"], "720p"),
            _ => value
        };
    }

    private string LocalizeFormatToken(string value)
    {
        var normalized = NormalizeChineseToken(value);
        return normalized switch
        {
            "auto" => Text["FormatAuto"],
            "unknown" => Text["FormatUnknown"],
            "audio" => Text["FormatAudio"],
            "best-audio" => Text["FormatBestAudio"],
            _ => value
        };
    }

    private static string NormalizeChineseToken(string value)
    {
        return value switch
        {
            "自动" or "鑷姩" => "auto",
            "未知" or "鏈煡" => "unknown",
            "音频" or "闊抽" => "audio",
            "最高可用" or "鏈€楂樺彲鐢?" => "best",
            "最佳音频" or "鏈€浣抽煶棰?" => "best-audio",
            "1080p 或以下" or "1080p 鎴栦互涓?" => "1080p-or-lower",
            "720p 或以下" or "720p 鎴栦互涓?" => "720p-or-lower",
            _ => value
        };
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
        Title = Text["TitleNotParsed"];
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

    private void RefreshComponents() => ComponentStatus = GetLocalizedComponentSummary();

    private void RefreshComponentsWithFeedback()
    {
        RefreshComponents();
        Stage = "组件检查";
        Status = "已重新检查组件状态";
        AddLog("已重新检查组件状态。");
        AddLog(GetLocalizedToolStatus());
    }

    private string GetLocalizedToolStatus()
    {
        var ytDlp = File.Exists(_toolPathService.YtDlpPath)
            ? _toolPathService.YtDlpPath
            : _toolPathService.HasYtDlp
                ? Text["ToolSystemPathYtDlp"]
                : Text["ToolMissing"];
        var ffmpeg = _toolPathService.FfmpegPath is not null && File.Exists(_toolPathService.FfmpegPath)
            ? _toolPathService.FfmpegPath
            : _toolPathService.HasFfmpeg
                ? Text["ToolSystemPathFfmpeg"]
                : Text["ToolMissing"];
        var jsRuntime = _toolPathService.JsRuntimePath ?? Text["ToolMissing"];

        return $"{Text["ToolYtDlp"]}: {ytDlp}\n{Text["ToolFfmpeg"]}: {ffmpeg}\n{Text["ToolJsRuntime"]}: {jsRuntime}";
    }

    private string GetLocalizedComponentSummary()
    {
        var ytDlp = _toolPathService.HasYtDlp ? Text["ToolNormal"] : Text["ToolMissing"];
        var ffmpeg = _toolPathService.HasFfmpeg ? Text["ToolNormal"] : Text["ToolMissing"];
        var jsRuntime = _toolPathService.JsRuntimePath is null ? Text["ToolRecommended"] : Text["ToolNormal"];

        return $"{Text["ToolYtDlp"]}: {ytDlp}    {Text["ToolFfmpeg"]}: {ffmpeg}    {Text["ToolJsRuntime"]}: {jsRuntime}\n{Text["ComponentHint"]}";
    }

    private bool ConfirmRestartForLanguageChange()
    {
        var dialog = new Window
        {
            Title = Text["LanguageRestartTitle"],
            Owner = Application.Current.MainWindow,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            ResizeMode = ResizeMode.NoResize,
            SizeToContent = SizeToContent.WidthAndHeight,
            MinWidth = 420,
            Background = Brushes.White,
            Content = BuildRestartDialogContent()
        };

        return dialog.ShowDialog() == true;
    }

    private UIElement BuildRestartDialogContent()
    {
        var root = new Grid { Margin = new Thickness(20) };
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var message = new TextBlock
        {
            Text = Text["LanguageRestartMessage"],
            TextWrapping = TextWrapping.Wrap,
            FontSize = 15,
            MaxWidth = 520,
            Margin = new Thickness(0, 0, 0, 20)
        };
        Grid.SetRow(message, 0);
        root.Children.Add(message);

        var buttons = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right
        };

        var restartButton = new Button
        {
            Content = Text["LanguageRestartYes"],
            MinWidth = 104,
            Margin = new Thickness(0, 0, 10, 0),
            IsDefault = true
        };
        restartButton.Click += (_, _) => Window.GetWindow(restartButton)!.DialogResult = true;

        var cancelButton = new Button
        {
            Content = Text["LanguageRestartNo"],
            MinWidth = 88,
            IsCancel = true
        };
        cancelButton.Click += (_, _) => Window.GetWindow(cancelButton)!.DialogResult = false;

        buttons.Children.Add(restartButton);
        buttons.Children.Add(cancelButton);
        Grid.SetRow(buttons, 1);
        root.Children.Add(buttons);

        return root;
    }

    private void RestartApplication()
    {
        try
        {
            var processPath = Environment.ProcessPath;
            if (!string.IsNullOrWhiteSpace(processPath))
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = processPath,
                    UseShellExecute = true
                });
            }

            Application.Current.Shutdown();
        }
        catch (Exception ex)
        {
            AddLog(ex.Message);
        }
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
            AddLog(GetLocalizedToolStatus());
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
            AddLog(GetLocalizedToolStatus());
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
    public override string ToString() => Label;

    public static FileConflictPolicyOption Rename(LocalizationService text) => new("rename", text["FileConflictRename"]);

    public static FileConflictPolicyOption FromValue(string value, LocalizationService text)
    {
        return value switch
        {
            "skip" => new FileConflictPolicyOption("skip", text["FileConflictSkip"]),
            "overwrite" => new FileConflictPolicyOption("overwrite", text["FileConflictOverwrite"]),
            _ => Rename(text)
        };
    }
}

public sealed record LanguageOption(string Value, string Label)
{
    public static LanguageOption Chinese { get; } = new(LocalizationService.Chinese, "简体中文");
    public static LanguageOption English { get; } = new(LocalizationService.English, "English");

    public override string ToString() => Label;

    public static LanguageOption FromValue(string? value)
    {
        return string.Equals(value, LocalizationService.Chinese, StringComparison.OrdinalIgnoreCase)
            ? Chinese
            : English;
    }
}


