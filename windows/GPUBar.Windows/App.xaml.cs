using System.Reflection;
using System.Windows;
using System.Windows.Threading;

namespace GPUBar.Windows;

public partial class App : System.Windows.Application
{
    private readonly SettingsStore _settingsStore = new();
    private readonly GpuStatusClient _client = new();
    private readonly Dictionary<string, int> _previousFreeByCluster = new(StringComparer.OrdinalIgnoreCase);

    private TrayManager? _trayManager;
    private DispatcherTimer? _pollTimer;
    private MainWindow? _mainWindow;
    private CancellationTokenSource? _refreshCts;

    public bool IsExiting { get; private set; }

    public MainViewModel ViewModel { get; private set; } = new(new AppSettings());

    protected override async void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        var settings = _settingsStore.Load();
        ViewModel = new MainViewModel(settings);
        _mainWindow = new MainWindow(ViewModel);
        _trayManager = new TrayManager(ShowMainWindow, () => _ = RefreshNowAsync(), ExitApplication);

        RegisterDeepLinkHandler();
        ApplyLaunchAtLoginSetting();

        if (e.Args.Length > 0 && UriActivation.TryApply(e.Args[0], settings))
        {
            _settingsStore.Save(settings);
            ShowMainWindow();
        }
        else if (!settings.IsPaired)
        {
            ShowMainWindow();
        }

        StartPolling();
        await RefreshNowAsync();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _pollTimer?.Stop();
        _refreshCts?.Cancel();
        _trayManager?.Dispose();
        _client.Dispose();
        base.OnExit(e);
    }

    public async Task SaveSettingsAsync()
    {
        _settingsStore.Save(ViewModel.Settings);
        RegisterDeepLinkHandler();
        ApplyLaunchAtLoginSetting();
        StartPolling();
        ViewModel.ResetStatus("Settings saved.");
        await RefreshNowAsync();
    }

    public async Task DisconnectAsync()
    {
        ViewModel.Settings.ApiUrl = AppSettings.DefaultApiUrl;
        ViewModel.Settings.CoreUrl = AppSettings.DefaultCoreUrl;
        ViewModel.Settings.ApiKey = string.Empty;
        ViewModel.Settings.Username = string.Empty;
        ViewModel.Clusters.Clear();
        ViewModel.PendingJobs.Clear();
        ViewModel.TopUsers.Clear();
        ViewModel.SelectedCluster = null;
        ViewModel.TotalFree = 0;
        ViewModel.TotalGpus = 0;
        ViewModel.LastUpdate = null;
        _settingsStore.Save(ViewModel.Settings);
        ViewModel.ResetStatus("Disconnected. Pair again from the dashboard.");
        UpdateTray();
        ShowMainWindow();
        await Task.CompletedTask;
    }

    public void RegisterDeepLinkHandler()
    {
        try
        {
            RegistryHelper.RegisterProtocolHandler(GetExecutablePath());
        }
        catch
        {
            // Best-effort only.
        }
    }

    public async Task RefreshNowAsync()
    {
        _refreshCts?.Cancel();
        _refreshCts = new CancellationTokenSource();
        ViewModel.IsLoading = true;
        UpdateTray();

        try
        {
            if (!ViewModel.Settings.IsPaired)
            {
                ViewModel.ResetStatus("Open the dashboard and click Link GPUBar to connect this device.");
                UpdateTray();
                return;
            }

            var response = await _client.FetchAsync(ViewModel.Settings, _refreshCts.Token);
            ViewModel.Apply(response);
            MaybeNotify(response);
        }
        catch (GpuStatusException ex)
        {
            ViewModel.SetError(ex.Message, ex.IsKeyInvalid);
        }
        catch (OperationCanceledException)
        {
            return;
        }
        catch (Exception ex)
        {
            ViewModel.SetError(ex.Message);
        }
        finally
        {
            ViewModel.IsLoading = false;
            UpdateTray();
        }
    }

    private void ShowMainWindow()
    {
        if (_mainWindow is null)
        {
            return;
        }

        if (!_mainWindow.IsVisible)
        {
            _mainWindow.Show();
        }

        if (_mainWindow.WindowState == WindowState.Minimized)
        {
            _mainWindow.WindowState = WindowState.Normal;
        }

        _mainWindow.Activate();
        _mainWindow.Topmost = true;
        _mainWindow.Topmost = false;
        _mainWindow.Focus();
    }

    private void ExitApplication()
    {
        IsExiting = true;
        _mainWindow?.Close();
        Shutdown();
    }

    private void StartPolling()
    {
        _pollTimer?.Stop();
        _pollTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromSeconds(ViewModel.Settings.RefreshIntervalSeconds),
        };
        _pollTimer.Tick += async (_, _) => await RefreshNowAsync();
        _pollTimer.Start();
    }

    private void ApplyLaunchAtLoginSetting()
    {
        try
        {
            RegistryHelper.ConfigureLaunchAtLogin(ViewModel.Settings.LaunchAtLogin, GetExecutablePath());
        }
        catch
        {
            // Best-effort only.
        }
    }

    private void UpdateTray()
    {
        _trayManager?.UpdateStatus(ViewModel.TotalFree, ViewModel.TotalGpus, ViewModel.StatusMessage, !string.IsNullOrWhiteSpace(ViewModel.ErrorMessage));
    }

    private void MaybeNotify(GpuStatusResponse response)
    {
        if (!ViewModel.Settings.NotifyOnFreeGpu)
        {
            return;
        }

        var filter = ViewModel.Settings.NotifyClusterFilter.Trim().ToLowerInvariant();
        var threshold = ViewModel.Settings.NotifyThreshold;
        var grouped = response.Nodes
            .GroupBy(node => node.Cluster.Trim().ToLowerInvariant())
            .ToDictionary(group => group.Key, group => group.Sum(node => node.GpuFree), StringComparer.OrdinalIgnoreCase);

        foreach (var (cluster, currentFree) in grouped)
        {
            if (!string.IsNullOrWhiteSpace(filter) && !cluster.Contains(filter, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            _previousFreeByCluster.TryGetValue(cluster, out var previousFree);
            _previousFreeByCluster[cluster] = currentFree;

            if (previousFree < threshold && currentFree >= threshold)
            {
                _trayManager?.ShowNotification("GPUs available", $"{cluster}: {currentFree} free");
            }
        }
    }

    private static string GetExecutablePath()
    {
        return Assembly.GetEntryAssembly()?.Location ?? Environment.ProcessPath ?? "GPUBar.Windows.exe";
    }
}
