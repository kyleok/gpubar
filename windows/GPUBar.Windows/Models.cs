using System.Collections.ObjectModel;
using System.Text.Json.Serialization;

namespace GPUBar.Windows;

public sealed class GpuStatusResponse
{
    [JsonPropertyName("summary")]
    public Summary Summary { get; set; } = new();

    [JsonPropertyName("users")]
    public List<UserUsage> Users { get; set; } = [];

    [JsonPropertyName("nodes")]
    public List<Node> Nodes { get; set; } = [];

    [JsonPropertyName("pending")]
    public List<PendingJob> Pending { get; set; } = [];

    public sealed class Summary
    {
        [JsonPropertyName("total")]
        public int Total { get; set; }

        [JsonPropertyName("used")]
        public int Used { get; set; }

        [JsonIgnore]
        public int Free => Total - Used;
    }

    public sealed class UserUsage
    {
        [JsonPropertyName("name")]
        public string Name { get; set; } = string.Empty;

        [JsonPropertyName("total")]
        public int Total { get; set; }

        [JsonPropertyName("clusters")]
        public Dictionary<string, int> Clusters { get; set; } = [];

        [JsonIgnore]
        public string ClusterSummary => string.Join(", ", Clusters.OrderByDescending(pair => pair.Value).Select(pair => $"{pair.Key}:{pair.Value}"));
    }

    public sealed class Node
    {
        [JsonPropertyName("name")]
        public string Name { get; set; } = string.Empty;

        [JsonPropertyName("cluster")]
        public string Cluster { get; set; } = string.Empty;

        [JsonPropertyName("partition")]
        public string? Partition { get; set; }

        [JsonPropertyName("gpu_type")]
        public string? GpuType { get; set; }

        [JsonPropertyName("gpu_total")]
        public int GpuTotal { get; set; }

        [JsonPropertyName("gpu_used")]
        public int GpuUsed { get; set; }

        [JsonPropertyName("gpu_free")]
        public int GpuFree { get; set; }

        [JsonPropertyName("status")]
        public string Status { get; set; } = string.Empty;

        [JsonPropertyName("users")]
        public List<NodeUser>? Users { get; set; }
    }

    public sealed class NodeUser
    {
        [JsonPropertyName("user")]
        public string User { get; set; } = string.Empty;

        [JsonPropertyName("gpus")]
        public int Gpus { get; set; }
    }

    public sealed class PendingJob
    {
        [JsonPropertyName("user")]
        public string User { get; set; } = string.Empty;

        [JsonPropertyName("cluster")]
        public string? Cluster { get; set; }

        [JsonPropertyName("partition")]
        public string? Partition { get; set; }

        [JsonPropertyName("gpus")]
        public int? Gpus { get; set; }

        [JsonPropertyName("job_name")]
        public string? JobName { get; set; }

        [JsonPropertyName("position")]
        public int? Position { get; set; }

        [JsonIgnore]
        public string Scope => string.Join(" • ", new[] { Cluster, Partition, JobName }.Where(value => !string.IsNullOrWhiteSpace(value)));
    }
}

public sealed class ClusterSummaryViewModel : ObservableObject
{
    private string _id = string.Empty;
    private string _displayName = string.Empty;
    private int _totalGpus;
    private int _usedGpus;
    private int _freeGpus;
    private string _gpuType = "GPU";
    private string _userSummary = string.Empty;

    public string Id
    {
        get => _id;
        set => SetProperty(ref _id, value);
    }

    public string DisplayName
    {
        get => _displayName;
        set => SetProperty(ref _displayName, value);
    }

    public int TotalGpus
    {
        get => _totalGpus;
        set
        {
            if (SetProperty(ref _totalGpus, value))
            {
                OnPropertyChanged(nameof(AvailabilityText));
                OnPropertyChanged(nameof(FreePercent));
            }
        }
    }

    public int UsedGpus
    {
        get => _usedGpus;
        set
        {
            if (SetProperty(ref _usedGpus, value))
            {
                OnPropertyChanged(nameof(AvailabilityText));
                OnPropertyChanged(nameof(FreePercent));
            }
        }
    }

    public int FreeGpus
    {
        get => _freeGpus;
        set
        {
            if (SetProperty(ref _freeGpus, value))
            {
                OnPropertyChanged(nameof(AvailabilityText));
                OnPropertyChanged(nameof(FreePercent));
            }
        }
    }

    public string GpuType
    {
        get => _gpuType;
        set => SetProperty(ref _gpuType, value);
    }

    public string UserSummary
    {
        get => _userSummary;
        set => SetProperty(ref _userSummary, value);
    }

    public ObservableCollection<NodeRowViewModel> Nodes { get; } = [];

    public ObservableCollection<GpuStatusResponse.PendingJob> PendingJobs { get; } = [];

    public string AvailabilityText => $"{FreeGpus} free / {TotalGpus} total";

    public double FreePercent => TotalGpus <= 0 ? 0 : (double)FreeGpus / TotalGpus * 100;
}

public sealed class NodeRowViewModel
{
    public required string Name { get; init; }
    public required string GpuType { get; init; }
    public required string Status { get; init; }
    public required int Total { get; init; }
    public required int Used { get; init; }
    public required int Free { get; init; }
    public required string Users { get; init; }
    public double FreePercent => Total <= 0 ? 0 : (double)Free / Total * 100;
}
