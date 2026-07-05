using YtDlpDownloader.Infrastructure;
using YtDlpDownloader.Models;

namespace YtDlpDownloader.ViewModels;

public sealed class DownloadTaskViewModel : ObservableObject
{
    private double _progress;
    private string _speed = "";
    private string _eta = "";
    private string _stage = "待开始";
    private string _message = "";

    public double Progress
    {
        get => _progress;
        set => SetProperty(ref _progress, value);
    }

    public string Speed
    {
        get => _speed;
        set => SetProperty(ref _speed, value);
    }

    public string Eta
    {
        get => _eta;
        set => SetProperty(ref _eta, value);
    }

    public string Stage
    {
        get => _stage;
        set => SetProperty(ref _stage, value);
    }

    public string Message
    {
        get => _message;
        set => SetProperty(ref _message, value);
    }

    public void Apply(DownloadProgress progress)
    {
        if (progress.Percentage is { } percentage)
        {
            Progress = percentage;
        }

        Speed = progress.Speed;
        Eta = progress.Eta;
        Stage = progress.Stage;
        Message = progress.Message;
    }
}
