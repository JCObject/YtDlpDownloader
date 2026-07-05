namespace YtDlpDownloader.Services;

public sealed class SettingsService
{
    public SettingsService(ToolPathService toolPathService)
    {
        DefaultDownloadDirectory = toolPathService.DefaultDownloadDirectory;
    }

    public string DefaultDownloadDirectory { get; }
}
