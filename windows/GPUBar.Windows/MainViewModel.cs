using System.Collections.ObjectModel;

namespace GPUBar.Windows;

public sealed class MainViewModel : ObservableObject
{
    private static readonly string[] PreferredClusterOrder = ["vegi", "potato", "soda", "independent"];

    private ClusterSummaryViewModel? _selectedCluster;
    private bool _isLoading;
    private bool _keyInvalid;
    private int _totalFree;
    private int _totalGpus;
    private DateTime? _lastUpdate;
    private string _errorMessage = string.Empty;
    private string _statusMessage = "Waiting for first refresh";

    public MainViewModel(AppSettings settings)
    {
        Settings = settings;
    }

    public AppSettings Settings { get; }

    public ObservableCollection<ClusterSummaryViewModel> Clusters { get; } = [];

    public ObservableCollection<GpuStatusResponse.PendingJob> PendingJobs { get; } = [];

    public ObservableCollection<GpuStatusResponse.UserUsage> TopUsers { get; } = [];

    public ClusterSummaryViewModel? SelectedCluster
    {
        get => _selectedCluster;
        set => SetProperty(ref _selectedCluster, value);
    }

    public bool IsLoading
    {
        get => _isLoading;
        set => SetProperty(ref _isLoading, value);
    }

    public bool KeyInvalid
    {
        get => _keyInvalid;
        set => SetProperty(ref _keyInvalid, value);
    }

    public int TotalFree
    {
        get => _totalFree;
        set
        {
            if (SetProperty(ref _totalFree, value))
            {
                OnPropertyChanged(nameof(AvailabilityText));
            }
        }
    }

    public int TotalGpus
    {
        get => _totalGpus;
        set
        {
            if (SetProperty(ref _totalGpus, value))
            {
                OnPropertyChanged(nameof(AvailabilityText));
            }
        }
    }

    public DateTime? LastUpdate
    {
        get => _lastUpdate;
        set
        {
            if (SetProperty(ref _lastUpdate, value))
            {
                OnPropertyChanged(nameof(LastUpdateText));
            }
        }
    }

    public string ErrorMessage
    {
        get => _errorMessage;
        set => SetProperty(ref _errorMessage, value);
    }

    public string StatusMessage
    {
        get => _statusMessage;
        set => SetProperty(ref _statusMessage, value);
    }

    public string AvailabilityText => $"{TotalFree} free / {TotalGpus} total";

    public string LastUpdateText => LastUpdate is null ? "Never refreshed" : $"Updated {LastUpdate.Value:t}";

    public void Apply(GpuStatusResponse response)
    {
        var clusterMap = new Dictionary<string, ClusterSummaryViewModel>(StringComparer.OrdinalIgnoreCase);

        foreach (var node in response.Nodes)
        {
            var clusterId = NormalizeClusterName(node.Cluster);
            if (!clusterMap.TryGetValue(clusterId, out var cluster))
            {
                cluster = new ClusterSummaryViewModel
                {
                    Id = clusterId,
                    DisplayName = clusterId,
                };
                clusterMap.Add(clusterId, cluster);
            }

            cluster.TotalGpus += node.GpuTotal;
            cluster.UsedGpus += node.GpuUsed;
            cluster.FreeGpus += node.GpuFree;
            cluster.GpuType = !string.IsNullOrWhiteSpace(node.GpuType) ? node.GpuType! : (!string.IsNullOrWhiteSpace(node.Partition) ? node.Partition! : "GPU");
            cluster.Nodes.Add(new NodeRowViewModel
            {
                Name = node.Name,
                GpuType = cluster.GpuType,
                Status = node.Status,
                Total = node.GpuTotal,
                Used = node.GpuUsed,
                Free = node.GpuFree,
                Users = string.Join("  ", (node.Users ?? []).OrderByDescending(user => user.Gpus).ThenBy(user => user.User).Select(user => $"{user.User} ({user.Gpus})")),
            });
        }

        foreach (var pendingJob in response.Pending)
        {
            if (string.IsNullOrWhiteSpace(pendingJob.Cluster))
            {
                continue;
            }

            var clusterId = NormalizeClusterName(pendingJob.Cluster!);
            if (clusterMap.TryGetValue(clusterId, out var cluster))
            {
                cluster.PendingJobs.Add(pendingJob);
            }
        }

        foreach (var cluster in clusterMap.Values)
        {
            cluster.UserSummary = string.Join(
                "  ",
                cluster.Nodes
                    .SelectMany(node => node.Users.Split("  ", StringSplitOptions.RemoveEmptyEntries))
                    .Take(4));
        }

        var orderedClusters = clusterMap.Values
            .OrderBy(cluster => ClusterSortKey(cluster.Id))
            .ThenBy(cluster => cluster.Id, StringComparer.OrdinalIgnoreCase)
            .ToList();

        Clusters.Clear();
        foreach (var cluster in orderedClusters)
        {
            Clusters.Add(cluster);
        }

        PendingJobs.Clear();
        foreach (var job in response.Pending)
        {
            PendingJobs.Add(job);
        }

        TopUsers.Clear();
        foreach (var user in response.Users.OrderByDescending(user => user.Total).ThenBy(user => user.Name, StringComparer.OrdinalIgnoreCase))
        {
            TopUsers.Add(user);
        }

        TotalFree = response.Summary.Free;
        TotalGpus = response.Summary.Total;
        LastUpdate = DateTime.Now;
        ErrorMessage = string.Empty;
        KeyInvalid = false;
        StatusMessage = $"{TotalFree} GPUs free across {Clusters.Count} clusters";

        if (SelectedCluster is null || !Clusters.Contains(SelectedCluster))
        {
            SelectedCluster = Clusters.FirstOrDefault();
        }
    }

    public void SetError(string message, bool keyInvalid = false)
    {
        ErrorMessage = message;
        KeyInvalid = keyInvalid;
        StatusMessage = message;
    }

    public void ResetStatus(string message)
    {
        ErrorMessage = string.Empty;
        StatusMessage = message;
        KeyInvalid = false;
    }

    private static string NormalizeClusterName(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? "unknown" : value.Trim().ToLowerInvariant();
    }

    private static int ClusterSortKey(string clusterId)
    {
        var index = Array.IndexOf(PreferredClusterOrder, clusterId);
        return index >= 0 ? index : int.MaxValue;
    }
}
