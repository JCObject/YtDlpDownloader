using System.IO;
using System.Text.Json;
using YtDlpDownloader.Models;

namespace YtDlpDownloader.Services;

public sealed class UserSettingsService
{
    private readonly string _settingsPath;

    public UserSettingsService()
    {
        var directory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "YtDlpDownloader");
        Directory.CreateDirectory(directory);
        _settingsPath = Path.Combine(directory, "settings.json");
    }

    public UserDownloadSettings Load()
    {
        if (!File.Exists(_settingsPath))
        {
            return new UserDownloadSettings();
        }

        try
        {
            var json = File.ReadAllText(_settingsPath);
            return JsonSerializer.Deserialize<UserDownloadSettings>(json) ?? new UserDownloadSettings();
        }
        catch
        {
            return new UserDownloadSettings();
        }
    }

    public void Save(UserDownloadSettings settings)
    {
        var json = JsonSerializer.Serialize(settings, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(_settingsPath, json);
    }
}
