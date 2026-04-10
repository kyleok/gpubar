using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace GPUBar.Windows;

public sealed class AppSettings : ObservableObject
{
    public const string DefaultApiUrl = "https://status.example.com";
    public const string DefaultCoreUrl = "https://core.example.com";
    public const int DefaultRefreshIntervalSeconds = 60;

    private string _apiUrl = DefaultApiUrl;
    private string _coreUrl = DefaultCoreUrl;
    private string _apiKey = string.Empty;
    private string _username = string.Empty;
    private int _refreshIntervalSeconds = DefaultRefreshIntervalSeconds;
    private bool _launchAtLogin;
    private bool _notifyOnFreeGpu;
    private int _notifyThreshold = 1;
    private string _notifyClusterFilter = string.Empty;

    [JsonPropertyName("apiUrl")]
    public string ApiUrl
    {
        get => _apiUrl;
        set
        {
            if (SetProperty(ref _apiUrl, NormalizeUrl(value, DefaultApiUrl)))
            {
                OnPropertyChanged(nameof(IsPaired));
            }
        }
    }

    [JsonPropertyName("coreUrl")]
    public string CoreUrl
    {
        get => _coreUrl;
        set => SetProperty(ref _coreUrl, NormalizeUrl(value, DefaultCoreUrl));
    }

    [JsonPropertyName("apiKey")]
    public string ApiKey
    {
        get => _apiKey;
        set
        {
            if (SetProperty(ref _apiKey, value.Trim()))
            {
                OnPropertyChanged(nameof(IsPaired));
            }
        }
    }

    [JsonPropertyName("username")]
    public string Username
    {
        get => _username;
        set => SetProperty(ref _username, value.Trim());
    }

    [JsonPropertyName("refreshIntervalSeconds")]
    public int RefreshIntervalSeconds
    {
        get => _refreshIntervalSeconds;
        set => SetProperty(ref _refreshIntervalSeconds, Math.Clamp(value <= 0 ? DefaultRefreshIntervalSeconds : value, 15, 900));
    }

    [JsonPropertyName("launchAtLogin")]
    public bool LaunchAtLogin
    {
        get => _launchAtLogin;
        set => SetProperty(ref _launchAtLogin, value);
    }

    [JsonPropertyName("notifyOnFreeGpu")]
    public bool NotifyOnFreeGpu
    {
        get => _notifyOnFreeGpu;
        set => SetProperty(ref _notifyOnFreeGpu, value);
    }

    [JsonPropertyName("notifyThreshold")]
    public int NotifyThreshold
    {
        get => _notifyThreshold;
        set => SetProperty(ref _notifyThreshold, Math.Clamp(value <= 0 ? 1 : value, 1, 64));
    }

    [JsonPropertyName("notifyClusterFilter")]
    public string NotifyClusterFilter
    {
        get => _notifyClusterFilter;
        set => SetProperty(ref _notifyClusterFilter, value.Trim());
    }

    [JsonIgnore]
    public bool IsPaired => !string.IsNullOrWhiteSpace(ApiKey) && !string.Equals(ApiUrl, DefaultApiUrl, StringComparison.OrdinalIgnoreCase);

    public AppSettings Clone()
    {
        return new AppSettings
        {
            ApiUrl = ApiUrl,
            CoreUrl = CoreUrl,
            ApiKey = ApiKey,
            Username = Username,
            RefreshIntervalSeconds = RefreshIntervalSeconds,
            LaunchAtLogin = LaunchAtLogin,
            NotifyOnFreeGpu = NotifyOnFreeGpu,
            NotifyThreshold = NotifyThreshold,
            NotifyClusterFilter = NotifyClusterFilter,
        };
    }

    private static string NormalizeUrl(string value, string fallback)
    {
        var trimmed = value.Trim();
        return string.IsNullOrWhiteSpace(trimmed) ? fallback : trimmed.TrimEnd('/');
    }
}

public sealed class SettingsStore
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    };

    private readonly string _settingsPath;

    public SettingsStore()
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        var directory = Path.Combine(appData, "GPUBar");
        Directory.CreateDirectory(directory);
        _settingsPath = Path.Combine(directory, "settings.json");
    }

    public AppSettings Load()
    {
        if (!File.Exists(_settingsPath))
        {
            return new AppSettings();
        }

        try
        {
            var json = File.ReadAllText(_settingsPath);
            return JsonSerializer.Deserialize<AppSettings>(json, JsonOptions) ?? new AppSettings();
        }
        catch
        {
            return new AppSettings();
        }
    }

    public void Save(AppSettings settings)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(_settingsPath)!);
        File.WriteAllText(_settingsPath, JsonSerializer.Serialize(settings, JsonOptions));
    }
}
