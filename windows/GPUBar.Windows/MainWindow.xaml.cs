using System.ComponentModel;
using System.Windows;

namespace GPUBar.Windows;

public partial class MainWindow : Window
{
    public MainWindow(MainViewModel viewModel)
    {
        InitializeComponent();
        DataContext = viewModel;
    }

    public MainViewModel ViewModel => (MainViewModel)DataContext;

    protected override void OnClosing(CancelEventArgs e)
    {
        if (((App)Application.Current).IsExiting)
        {
            base.OnClosing(e);
            return;
        }

        e.Cancel = true;
        Hide();
    }

    private async void RefreshButton_OnClick(object sender, RoutedEventArgs e)
    {
        await ((App)Application.Current).RefreshNowAsync();
    }

    private void HideButton_OnClick(object sender, RoutedEventArgs e)
    {
        Hide();
    }

    private async void SaveSettingsButton_OnClick(object sender, RoutedEventArgs e)
    {
        await ((App)Application.Current).SaveSettingsAsync();
    }

    private void RegisterDeepLinkButton_OnClick(object sender, RoutedEventArgs e)
    {
        ((App)Application.Current).RegisterDeepLinkHandler();
        MessageBox.Show(this, "GPUBar registered the gpubar:// protocol for this Windows account.", "GPUBar", MessageBoxButton.OK, MessageBoxImage.Information);
    }

    private async void DisconnectButton_OnClick(object sender, RoutedEventArgs e)
    {
        await ((App)Application.Current).DisconnectAsync();
    }
}
