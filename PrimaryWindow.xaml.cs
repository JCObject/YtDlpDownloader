using System.Windows;
using System.Windows.Controls;
using YtDlpDownloader.ViewModels;

namespace YtDlpDownloader;

public partial class PrimaryWindow : Window
{
    public PrimaryWindow()
    {
        InitializeComponent();
        DataContext = new PrimaryViewModel();
    }

    private void LogBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        if (sender is TextBox textBox)
        {
            textBox.ScrollToEnd();
        }
    }
}
