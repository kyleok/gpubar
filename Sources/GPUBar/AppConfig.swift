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
    var selectedTabID: String
    var visibleTabIDs: [String]
    var overviewSectionIDs: [String]

    static let defaultURL = "https://status.example.com"
    static let defaultCoreURL = "https://core.example.com"
    static let defaultInterval: TimeInterval = 60

    var isPaired: Bool { !apiKey.isEmpty && apiURL != Self.defaultURL }

    var selectedTab: DashboardTab {
        get {
            DashboardTab(rawValue: selectedTabID) ?? visibleTabs.first ?? .overview
        }
        set {
            selectedTabID = newValue.rawValue
        }
    }

    var visibleTabs: [DashboardTab] {
        get {
            visibleTabIDs
                .compactMap(DashboardTab.init(rawValue:))
                .normalizedVisibleTabs()
        }
        set {
            visibleTabIDs = newValue.normalizedVisibleTabs().map(\.rawValue)
            ensureValidSelection()
        }
    }

    var overviewSections: [OverviewSection] {
        get {
            overviewSectionIDs
                .compactMap(OverviewSection.init(rawValue:))
                .normalizedOverviewSections()
        }
        set {
            overviewSectionIDs = newValue.normalizedOverviewSections().map(\.rawValue)
        }
    }

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
        selectedTabID = UserDefaults.standard.string(forKey: "selectedTabID") ?? DashboardTab.overview.rawValue
        visibleTabIDs = UserDefaults.standard.stringArray(forKey: "visibleTabIDs") ?? Array.defaultVisibleTabs.map(\.rawValue)
        overviewSectionIDs = UserDefaults.standard.stringArray(forKey: "overviewSectionIDs") ?? Array.defaultOverviewSections.map(\.rawValue)
        ensureValidSelection()
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
        UserDefaults.standard.set(visibleTabs.map(\.rawValue), forKey: "visibleTabIDs")
        UserDefaults.standard.set(overviewSections.map(\.rawValue), forKey: "overviewSectionIDs")
        UserDefaults.standard.set(selectedTab.rawValue, forKey: "selectedTabID")
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

    mutating func ensureValidSelection() {
        visibleTabIDs = visibleTabs.map(\.rawValue)
        overviewSectionIDs = overviewSections.map(\.rawValue)
        if !visibleTabs.contains(selectedTab) {
            selectedTabID = visibleTabs.first?.rawValue ?? DashboardTab.overview.rawValue
        }
    }
}

extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}

extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
