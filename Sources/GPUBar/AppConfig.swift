import Foundation

struct AppConfig {
    var apiURL: String
    var coreURL: String
    var apiKey: String
    var username: String
    var refreshInterval: TimeInterval
    var launchAtLogin: Bool
    var notifyOnFreeGPU: Bool
    var notifyThreshold: Int  // Notify when N+ GPUs are free
    var notifyClusterFilter: String  // Empty = all clusters
    var switcherShowsIcons: Bool
    var showOverviewTab: Bool
    var visibleClusterTabs: [String]
    var overviewSelectedClusters: [String]

    static let defaultURL = "https://status.example.com"
    static let defaultCoreURL = "https://core.example.com"
    static let defaultInterval: TimeInterval = 60
    static let preferredClusterOrder = ["vegi", "potato", "soda", "independent"]

    var isPaired: Bool { !apiKey.isEmpty && apiURL != Self.defaultURL }

    init() {
        apiURL = UserDefaults.standard.string(forKey: "apiURL") ?? Self.defaultURL
        coreURL = UserDefaults.standard.string(forKey: "coreURL") ?? Self.defaultCoreURL
        apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        username = UserDefaults.standard.string(forKey: "username") ?? ""
        refreshInterval = UserDefaults.standard.double(forKey: "refreshInterval").nonZero ?? Self.defaultInterval
        launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        notifyOnFreeGPU = UserDefaults.standard.bool(forKey: "notifyOnFreeGPU")
        notifyThreshold = UserDefaults.standard.integer(forKey: "notifyThreshold").nonZero ?? 1
        notifyClusterFilter = UserDefaults.standard.string(forKey: "notifyClusterFilter") ?? ""
        switcherShowsIcons = UserDefaults.standard.object(forKey: "switcherShowsIcons") as? Bool ?? true
        showOverviewTab = UserDefaults.standard.object(forKey: "showOverviewTab") as? Bool ?? true
        if UserDefaults.standard.object(forKey: "visibleClusterTabs") != nil {
            visibleClusterTabs = Self.sanitizeClusterNames(
                UserDefaults.standard.stringArray(forKey: "visibleClusterTabs") ?? [])
        } else {
            visibleClusterTabs = Self.preferredClusterOrder
        }
        if UserDefaults.standard.object(forKey: "overviewSelectedClusters") != nil {
            overviewSelectedClusters = Self.sanitizeClusterNames(
                UserDefaults.standard.stringArray(forKey: "overviewSelectedClusters") ?? [])
        } else {
            overviewSelectedClusters = Self.preferredClusterOrder
        }
    }

    func save() {
        UserDefaults.standard.set(apiURL, forKey: "apiURL")
        UserDefaults.standard.set(coreURL, forKey: "coreURL")
        UserDefaults.standard.set(apiKey, forKey: "apiKey")
        UserDefaults.standard.set(username, forKey: "username")
        UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
        UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
        UserDefaults.standard.set(notifyOnFreeGPU, forKey: "notifyOnFreeGPU")
        UserDefaults.standard.set(notifyThreshold, forKey: "notifyThreshold")
        UserDefaults.standard.set(notifyClusterFilter, forKey: "notifyClusterFilter")
        UserDefaults.standard.set(switcherShowsIcons, forKey: "switcherShowsIcons")
        UserDefaults.standard.set(showOverviewTab, forKey: "showOverviewTab")
        UserDefaults.standard.set(Self.sanitizeClusterNames(visibleClusterTabs), forKey: "visibleClusterTabs")
        UserDefaults.standard.set(Self.sanitizeClusterNames(overviewSelectedClusters), forKey: "overviewSelectedClusters")
    }

    mutating func disconnect() {
        apiKey = ""
        username = ""
        apiURL = Self.defaultURL
        coreURL = Self.defaultCoreURL
        UserDefaults.standard.removeObject(forKey: "apiURL")
        UserDefaults.standard.removeObject(forKey: "coreURL")
        UserDefaults.standard.removeObject(forKey: "apiKey")
        UserDefaults.standard.removeObject(forKey: "username")
    }

    static func orderedClusterOptions(available: [String]) -> [String] {
        let normalizedAvailable = sanitizeClusterNames(available)
        let preferred = preferredClusterOrder.filter { normalizedAvailable.contains($0) }
        let extras = normalizedAvailable.filter { !preferred.contains($0) }
        return preferred + extras
    }

    static func sanitizeClusterNames(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }

    static func normalizeClusterNames(_ values: [String], fallback: [String]) -> [String] {
        let sanitized = sanitizeClusterNames(values)
        return sanitized.isEmpty ? fallback : sanitized
    }

    static func displayName(for clusterID: String) -> String {
        clusterID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}

extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
