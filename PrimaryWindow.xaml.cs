using System.Windows;
using System.Windows.Controls;
using YtDlpDownloader.ViewModels;

namespace YtDlpDownloader;

public partial class PrimaryWindow : Window
{
    public PrimaryWindow()
    {
        InitializeComponent();
        var viewModel = new PrimaryViewModel();
        DataContext = viewModel;
        ApplyColumnHeaders(viewModel);
    }

    private void ApplyColumnHeaders(PrimaryViewModel viewModel)
    {
        SimpleOptionColumn.Header = viewModel.Text["ColumnOption"];
        SimpleKindColumn.Header = viewModel.Text["ColumnKind"];
        SimpleResolutionColumn.Header = viewModel.Text["ColumnResolution"];
        SimpleFormatColumn.Header = viewModel.Text["ColumnFormat"];
        SimpleSummaryColumn.Header = viewModel.Text["ColumnSummary"];

        AdvancedResolutionColumn.Header = viewModel.Text["ColumnResolution"];
        AdvancedKindColumn.Header = viewModel.Text["ColumnKind"];
        AdvancedFormatColumn.Header = viewModel.Text["ColumnFormat"];
        AdvancedVideoCodecColumn.Header = viewModel.Text["ColumnVideoCodec"];
        AdvancedAudioCodecColumn.Header = viewModel.Text["ColumnAudioCodec"];
        AdvancedSizeColumn.Header = viewModel.Text["ColumnSize"];
        AdvancedExpressionColumn.Header = viewModel.Text["ColumnExpression"];
    }

    private void LogBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        if (sender is TextBox textBox)
        {
            textBox.ScrollToEnd();
        }
    }
}
